import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/patient/domain/patient.dart';
import 'package:nurse_pulse_app/features/sbar/application/sbar_notifier.dart';
import 'package:nurse_pulse_app/features/sbar/domain/sbar_transfer.dart';
import 'package:nurse_pulse_app/features/sbar/infrastructure/sbar_api.dart';

import '../patient/fixtures.dart';
import 'fixtures.dart';

void main() {
  late FakeSbarApi api;
  late SbarNotifier notifier;
  User? user;
  late List<User> users;
  var patientReads = 0, directoryReads = 0, auditCalls = 0, invalidations = 0;
  Object? auditFailure, patientsFailure;
  late Future<Patient> Function(String) getPatient;

  setUp(() {
    api = FakeSbarApi();
    user = actor;
    users = [actor, receiver];
    patientReads = directoryReads = auditCalls = invalidations = 0;
    auditFailure = patientsFailure = null;
    getPatient = (id) async {
      patientReads++;
      return patientFrom(patientCommand(), id: id);
    };
    notifier = SbarNotifier(
      api,
      () => user,
      () async {
        if (patientsFailure != null) throw patientsFailure!;
        return [patientFrom(patientCommand())];
      },
      (id) => getPatient(id),
      () async {
        directoryReads++;
        return users;
      },
      audit: (id, patient, staff) async {
        auditCalls++;
        expect(staff.username, actor.username);
        if (auditFailure != null) throw auditFailure!;
      },
      onChanged: (_) => invalidations++,
    );
  });
  tearDown(() {
    if (notifier.mounted) notifier.dispose();
  });

  test('inválidos no consultan APIs ni escriben', () async {
    for (final c in [
      command(target: null),
      command(target: '2'),
      command(patientId: 'abc'),
      command(situation: 'x' * 7),
      command(background: 'x' * 1001),
      command(assessment: ' '),
      command(recommendation: 'x' * 7),
    ]) {
      await expectLater(notifier.register(c), throwsFormatException);
    }
    expect(api.posts, 0);
    expect(patientReads, 0);
    expect(directoryReads, 0);
  });
  test(
    'Doctor, desconocido y sin sesión no crean ni confirman recepción',
    () async {
      for (final staff in [
        const User(id: '2', username: 'doctor', roles: [kRoleDoctor]),
        const User(id: '2', username: 'unknown', roles: []),
        null,
      ]) {
        user = staff;
        await expectLater(notifier.register(command()), throwsFormatException);
        await expectLater(notifier.acknowledge('9'), throwsFormatException);
      }
      expect(api.posts + api.patches, 0);
      expect(api.detailReads, 0);
    },
  );
  for (final role in [kRoleNurse, kRoleAdmin]) {
    test('$role crea, normaliza y actualiza listado/detalle', () async {
      user = User(id: actor.id, username: actor.username, roles: [role]);
      final result = await notifier.register(command());
      expect(result.id, '9');
      expect(api.sent!.situation, 'Situación ficticia');
      expect(api.sent!.targetNurseId, '3');
      expect(notifier.state.transfers.single.id, '9');
      expect(auditCalls, 1);
      expect(invalidations, 1);
      expect(notifier.state.saving, isFalse);
    });
  }
  test('receptor inexistente, Doctor o propio no llega al POST', () async {
    for (final directory in [
      <User>[],
      [actor],
      [
        const User(id: '3', username: 'doctor', roles: [kRoleDoctor]),
      ],
    ]) {
      users = directory;
      await expectLater(notifier.register(command()), throwsFormatException);
    }
    expect(api.posts, 0);
    expect(notifier.state.saving, isFalse);
  });
  test('paciente desaparecido o distinto bloquea POST', () async {
    getPatient = (_) async => throw httpFailure(404);
    await expectLater(
      notifier.register(command()),
      throwsA(isA<DioException>()),
    );
    getPatient = (_) async => patientFrom(patientCommand(), id: '999');
    await expectLater(notifier.register(command()), throwsFormatException);
    expect(api.posts, 0);
  });
  test('doble registro y load durante escritura no repiten POST', () async {
    final pending = Completer<SbarWriteReceipt>();
    api.writing = () => pending.future;
    final first = notifier.register(command());
    await Future<void>.delayed(Duration.zero);
    await expectLater(notifier.register(command()), throwsFormatException);
    await notifier.load();
    expect(api.posts, 1);
    expect(api.listReads, 0);
    pending.complete(SbarWriteReceipt(id: '9', transfer: transfer()));
    await first;
    expect(notifier.state.saving, isFalse);
  });
  test('cambio de sesión durante consultas previas no escribe', () async {
    final pending = Completer<Patient>();
    getPatient = (_) => pending.future;
    final result = notifier.register(command());
    user = null;
    pending.complete(patientFrom(patientCommand()));
    await expectLater(result, throwsFormatException);
    expect(api.posts, 0);
  });
  test('dispose antes de crear no escribe', () async {
    final pending = Completer<Patient>();
    getPatient = (_) => pending.future;
    final result = notifier.register(command());
    notifier.dispose();
    pending.complete(patientFrom(patientCommand()));
    await expectLater(result, throwsFormatException);
    expect(api.posts, 0);
  });
  for (final status in [400, 401, 403, 409]) {
    test(
      'POST $status conserva listado y permite reintento explícito',
      () async {
        api.transfers = [transfer(id: '8')];
        await notifier.load();
        api.failure = httpFailure(status);
        await expectLater(
          notifier.register(command()),
          throwsA(isA<DioException>()),
        );
        expect(notifier.state.transfers.single.id, '8');
        expect(notifier.state.saving, isFalse);
        expect(auditCalls, 0);
        api.failure = null;
        await notifier.register(command());
        expect(api.posts, 2);
        expect(notifier.state.transfers, hasLength(2));
      },
    );
    test('PATCH $status conserva PENDING y no reintenta solo', () async {
      api.transfers = [transfer()];
      await notifier.load();
      api.failure = httpFailure(status);
      await expectLater(
        notifier.acknowledge('9'),
        throwsA(isA<DioException>()),
      );
      expect(notifier.state.transfers.single.status, 'PENDING');
      expect(notifier.state.saving, isFalse);
      expect(api.patches, 1);
      expect(notifier.state.confirmedAcknowledgements, isEmpty);
    });
  }
  test(
    'POST confirmado pero GET fallido devuelve ID y aviso sin inventar detalle',
    () async {
      api.receipt = SbarWriteReceipt(id: '9', readError: httpFailure(503));
      final result = await notifier.register(command());
      expect(result.id, '9');
      expect(notifier.state.transfers, isEmpty);
      expect(notifier.state.warning, contains('no vuelvas a registrarlo'));
      expect(api.posts, 1);
      expect(auditCalls, 1);
      expect(invalidations, 1);
    },
  );
  test(
    'respuesta confirmada sin ID válido no inventa entidad ni auditoría',
    () async {
      api.receipt = const SbarWriteReceipt(
        readError: FormatException('ID ausente'),
      );
      await notifier.register(command());
      expect(notifier.state.transfers, isEmpty);
      expect(notifier.state.warning, isNotNull);
      expect(api.posts, 1);
      expect(auditCalls, 0);
    },
  );
  test('fallo de auditoría no revierte registro confirmado', () async {
    auditFailure = StateError('Auditoría simulada');
    await notifier.register(command());
    expect(notifier.state.transfers.single.id, '9');
    expect(notifier.state.warning, contains('auditoría'));
    expect(api.posts, 1);
    notifier.clearWarning();
    expect(notifier.state.warning, isNull);
  });
  test('doble recepción y futuras pulsaciones solo hacen un PATCH', () async {
    final pending = Completer<SbarWriteReceipt>();
    api.writing = () => pending.future;
    final first = notifier.acknowledge('9');
    await Future<void>.delayed(Duration.zero);
    await expectLater(notifier.acknowledge('9'), throwsFormatException);
    expect(api.patches, 1);
    pending.complete(
      SbarWriteReceipt(
        id: '9',
        transfer: transfer(status: 'ACKNOWLEDGED'),
      ),
    );
    await first;
    await notifier.acknowledge('9');
    expect(api.patches, 1);
    expect(api.sentNotes, sbarAcknowledgementNotes);
    expect(notifier.state.transfers.single.status, 'ACKNOWLEDGED');
  });
  test(
    'PATCH confirmado con respuesta ilegible bloquea repetir recepción',
    () async {
      api.receipt = SbarWriteReceipt(id: '9', readError: httpFailure(500));
      await notifier.acknowledge('9');
      await notifier.acknowledge('9');
      expect(api.patches, 1);
      expect(notifier.state.warning, contains('no repitas la recepción'));
      expect(notifier.state.confirmedAcknowledgements, contains('9'));
    },
  );
  test('estado cambiado en servidor actualiza lista sin otro PATCH', () async {
    api.detail = (_) async => transfer(status: 'ACKNOWLEDGED');
    await notifier.acknowledge('9');
    expect(api.patches, 0);
    expect(notifier.state.transfers.single.status, 'ACKNOWLEDGED');
  });
  test('fallo de lectura previo a recepción no llega a PATCH', () async {
    api.detailFailure = httpFailure(404);
    await expectLater(notifier.acknowledge('9'), throwsA(isA<DioException>()));
    expect(api.patches, 0);
    expect(notifier.state.saving, isFalse);
  });
  test(
    'carga ordena fechas desconocidas al final, errores no borran datos',
    () async {
      api.transfers = [
        transfer(id: '7', date: null),
        transfer(id: '8', date: '2025-01-01T00:00:00Z'),
        transfer(),
      ];
      await notifier.load();
      expect(notifier.state.transfers.map((t) => t.id), ['9', '8', '7']);
      expect((await notifier.loadForPatient('1')).map((t) => t.id), [
        '9',
        '8',
        '7',
      ]);
      patientsFailure = httpFailure(500);
      await notifier.load();
      expect(notifier.state.transfers, hasLength(3));
      expect(notifier.state.error, isNotNull);
      expect(notifier.state.loading, isFalse);
      patientsFailure = null;
      api.failure = httpFailure(503);
      await notifier.load();
      expect(notifier.state.transfers, hasLength(3));
      api.failure = null;
      await notifier.load();
      expect(notifier.state.error, isNull);
    },
  );
  test('carga antigua no borra escritura reciente', () async {
    final pending = Completer<List<SbarTransfer>>();
    api.listing = (_) => pending.future;
    final loading = notifier.load();
    await Future<void>.delayed(Duration.zero);
    await notifier.register(command());
    pending.complete([]);
    await loading;
    expect(notifier.state.transfers.single.id, '9');
  });
  test('Doctor consulta; desconocido no llama API ni catálogo', () async {
    user = const User(id: '2', username: 'doctor', roles: [kRoleDoctor]);
    await notifier.load();
    expect(api.listReads, 1);
    user = null;
    await notifier.load();
    await expectLater(notifier.loadForPatient('1'), throwsFormatException);
    expect(api.listReads, 1);
  });
  test('error de conexión libera saving y no genera éxito', () async {
    api.failure = DioException(
      requestOptions: RequestOptions(path: '/handovers'),
      type: DioExceptionType.connectionError,
    );
    await expectLater(
      notifier.register(command()),
      throwsA(isA<DioException>()),
    );
    expect(notifier.state.transfers, isEmpty);
    expect(api.posts, 1);
    expect(notifier.state.saving, isFalse);
  });
}
