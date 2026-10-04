import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/clinical_event/application/clinical_event_effects.dart';
import 'package:nurse_pulse_app/features/clinical_event/application/clinical_event_notifier.dart';
import 'package:nurse_pulse_app/features/clinical_event/domain/clinical_event.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/patient/domain/patient.dart';

import '../patient/fixtures.dart';
import 'fixtures.dart';

void main() {
  late FakeEventApi api;
  late ClinicalEventNotifier notifier;
  User? user;
  var patientReads = 0, auditCalls = 0, alertCalls = 0, invalidations = 0;
  late Future<Patient> Function(String) patientRead;
  Object? auditFailure, alertFailure;

  setUp(() {
    api = FakeEventApi();
    user = actor;
    patientReads = auditCalls = alertCalls = invalidations = 0;
    auditFailure = alertFailure = null;
    patientRead = (id) async {
      patientReads++;
      return patientFrom(patientCommand(), id: id);
    };
    notifier = ClinicalEventNotifier(
      api,
      () => user,
      (id) => patientRead(id),
      ClinicalEventEffects(
        audit: (event, staff) async {
          auditCalls++;
          expect(staff.username, actor.username);
          if (auditFailure != null) throw auditFailure!;
        },
        createAlert: (event, staff) async {
          alertCalls++;
          if (alertFailure != null) throw alertFailure!;
        },
      ),
      onSaved: (_) => invalidations++,
    );
  });
  tearDown(() {
    if (notifier.mounted) notifier.dispose();
  });

  test('inválidos no llaman ninguna API, ni siquiera al paciente', () async {
    for (final c in [
      command(title: 'abc'),
      command(title: 'x' * 121),
      command(description: 'x' * 9),
      command(description: 'x' * 1001),
      command(patientId: 'abc'),
      command(type: 'UNKNOWN'),
      command(severity: 'UNKNOWN'),
    ]) {
      await expectLater(notifier.register(c), throwsFormatException);
    }
    expect(api.writes, 0);
    expect(patientReads, 0);
    expect(notifier.state.saving, isFalse);
  });
  test('sin sesión ni rol conocido no registra ni consulta', () async {
    for (final staff in [
      null,
      const User(id: '2', username: 'unknown', roles: []),
    ]) {
      user = staff;
      await expectLater(notifier.register(command()), throwsFormatException);
      await notifier.load();
      await expectLater(notifier.loadForPatient('1'), throwsFormatException);
    }
    expect(api.writes, 0);
    expect(api.reads, 0);
    expect(patientReads, 0);
  });
  for (final role in [kRoleNurse, kRoleDoctor, kRoleAdmin]) {
    test(
      '$role registra payload normalizado y actualiza lista/historial',
      () async {
        user = User(id: actor.id, username: actor.username, roles: [role]);
        final created = await notifier.register(command());
        expect(api.writes, 1);
        expect(api.sent!.title, 'Control');
        expect(api.sent!.description, 'Observación ficticia');
        expect(notifier.state.events.single, same(created));
        expect(auditCalls, 1);
        expect(alertCalls, 0);
        expect(invalidations, 1);
        expect(notifier.state.saving, isFalse);
      },
    );
  }
  test('doble envío y recarga durante POST no repiten escrituras', () async {
    final pending = Completer<ClinicalEvent>();
    api.writing = (_) => pending.future;
    final first = notifier.register(command());
    await Future<void>.delayed(Duration.zero);
    await expectLater(notifier.register(command()), throwsFormatException);
    await notifier.load();
    expect(api.writes, 1);
    expect(api.reads, 0);
    pending.complete(eventFrom(command()));
    await first;
    expect(notifier.state.saving, isFalse);
  });
  test('paciente inexistente o respuesta de otro ID bloquea POST', () async {
    patientRead = (_) async => throw httpFailure(404);
    await expectLater(
      notifier.register(command()),
      throwsA(isA<DioException>()),
    );
    patientRead = (_) async => patientFrom(patientCommand(), id: '999');
    await expectLater(notifier.register(command()), throwsFormatException);
    expect(api.writes, 0);
    expect(notifier.state.saving, isFalse);
  });
  test('cambio de sesión durante consulta de paciente bloquea POST', () async {
    final pending = Completer<Patient>();
    patientRead = (_) => pending.future;
    final result = notifier.register(command());
    user = null;
    pending.complete(patientFrom(patientCommand()));
    await expectLater(result, throwsFormatException);
    expect(api.writes, 0);
  });
  test('dispose antes de POST cancela sin escribir', () async {
    final pending = Completer<Patient>();
    patientRead = (_) => pending.future;
    final result = notifier.register(command());
    notifier.dispose();
    pending.complete(patientFrom(patientCommand()));
    await expectLater(result, throwsFormatException);
    expect(api.writes, 0);
  });
  for (final status in [400, 401, 403, 409]) {
    test(
      'HTTP $status conserva lista, libera saving y permite retry explícito',
      () async {
        api.events = [eventFrom(command(), id: 'old')];
        await notifier.load();
        api.failure = httpFailure(status);
        await expectLater(
          notifier.register(command()),
          throwsA(isA<DioException>()),
        );
        expect(notifier.state.events.single.id, 'old');
        expect(notifier.state.saving, isFalse);
        expect(auditCalls, 0);
        expect(alertCalls, 0);
        api.failure = null;
        await notifier.register(command());
        expect(api.writes, 2);
        expect(notifier.state.events, hasLength(2));
      },
    );
  }
  test(
    'error de conexión no inventa éxito ni reintenta automáticamente',
    () async {
      api.failure = DioException(
        requestOptions: RequestOptions(path: '/clinical-events'),
        type: DioExceptionType.connectionError,
      );
      await expectLater(
        notifier.register(command()),
        throwsA(isA<DioException>()),
      );
      expect(api.writes, 1);
      expect(notifier.state.events, isEmpty);
      expect(notifier.state.saving, isFalse);
    },
  );
  for (final severity in ['LOW', 'MODERATE', 'HIGH', 'CRITICAL']) {
    test('efectos para severidad $severity', () async {
      await notifier.register(command(severity: severity));
      expect(auditCalls, 1);
      expect(alertCalls, ['HIGH', 'CRITICAL'].contains(severity) ? 1 : 0);
    });
  }
  test(
    'fallan efectos: evento sigue confirmado, advertencia y ningún nuevo POST',
    () async {
      auditFailure = StateError('Auditoría simulada');
      alertFailure = StateError('Alerta simulada');
      final created = await notifier.register(command(severity: 'CRITICAL'));
      expect(notifier.state.events.single, same(created));
      expect(notifier.state.warning, contains('auditoría'));
      expect(notifier.state.warning, contains('Revisa Alertas'));
      expect(invalidations, 1);
      expect(api.writes, 1);
      notifier.clearWarning();
      expect(notifier.state.warning, isNull);
    },
  );
  test('lista/historial ordenados y refresh fallido conserva datos', () async {
    api.events = [
      eventFrom(command(), id: 'old', date: DateTime(2025)),
      eventFrom(command(), id: 'new', date: DateTime(2026)),
    ];
    await notifier.load();
    expect(notifier.state.events.map((e) => e.id), ['new', 'old']);
    expect((await notifier.loadForPatient('1')).map((e) => e.id), [
      'new',
      'old',
    ]);
    api.failure = httpFailure(500);
    await notifier.load();
    expect(notifier.state.events, hasLength(2));
    expect(notifier.state.error, isNotNull);
    api.failure = null;
    await notifier.load();
    expect(notifier.state.error, isNull);
  });
  test('carga antigua no borra registro reciente', () async {
    final pending = Completer<List<ClinicalEvent>>();
    api.loading = () => pending.future;
    final loading = notifier.load();
    await notifier.register(command());
    pending.complete([]);
    await loading;
    expect(notifier.state.events, hasLength(1));
    expect(notifier.state.loading, isFalse);
  });
  test('respuesta después de dispose no modifica estado desmontado', () async {
    final pending = Completer<ClinicalEvent>();
    api.writing = (_) => pending.future;
    final result = notifier.register(command());
    await Future<void>.delayed(Duration.zero);
    notifier.dispose();
    pending.complete(eventFrom(command()));
    expect(await result, isA<ClinicalEvent>());
    expect(api.writes, 1);
  });
}
