import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/dashboard/application/dashboard_notifier.dart';
import 'package:nurse_pulse_app/features/dashboard/domain/dashboard_summary.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';

import 'fixtures.dart';

void main() {
  late FakeDashboardApi api;
  late DashboardNotifier notifier;
  User? user;
  setUp(() {
    api = FakeDashboardApi();
    user = nurse;
    notifier = DashboardNotifier(api, () => user, clock: () => now);
  });
  tearDown(() {
    if (notifier.mounted) notifier.dispose();
  });

  for (final staff in [nurse, doctor, admin]) {
    test('${staff.username}: carga tipada y auditoría con permiso', () async {
      user = staff;
      api.snapshot = data(
        patients: [patient()],
        audits: staff == nurse ? null : [audit()],
      );
      await notifier.load();
      expect(api.reads, 1);
      expect(api.includeAudit, staff != nurse);
      expect(notifier.state.summary!.monitoredPatients, 1);
      expect(notifier.state.summary!.lastUpdate, now);
      expect(notifier.state.loading, isFalse);
      expect(notifier.state.error, isNull);
    });
  }
  test('sin sesión o rol no llama API', () async {
    for (final staff in [
      null,
      const User(id: '7', username: 'unknown', roles: []),
    ]) {
      user = staff;
      await notifier.load();
      expect(notifier.state.error, contains('permiso'));
      expect(notifier.state.summary, isNull);
    }
    expect(api.reads, 0);
  });
  test('refresh duplicado comparte lectura pendiente', () async {
    final gate = Completer<DashboardData>();
    api.loading = () => gate.future;
    final first = notifier.load(), second = notifier.load();
    expect(api.reads, 1);
    expect(notifier.state.loading, isTrue);
    gate.complete(data(patients: [patient()]));
    await Future.wait([first, second]);
    expect(notifier.state.summary!.monitoredPatients, 1);
  });
  for (final code in [400, 401, 403, 404, 409, 503]) {
    test(
      'HTTP $code conserva última carga sin inventar ceros y permite retry',
      () async {
        api.snapshot = data(patients: [patient()]);
        await notifier.load();
        api.failure = httpFailure(code);
        await notifier.load();
        expect(notifier.state.error, contains('$code'));
        expect(notifier.state.summary!.monitoredPatients, 1);
        expect(notifier.state.loading, isFalse);
        api.failure = null;
        api.snapshot = data();
        await notifier.load();
        expect(notifier.state.error, isNull);
        expect(notifier.state.summary!.monitoredPatients, 0);
      },
    );
  }
  test('primer fallo no inventa resumen', () async {
    api.failure = const FormatException('Respuesta inválida');
    await notifier.load();
    expect(notifier.state.summary, isNull);
    expect(notifier.state.data, isNull);
    expect(notifier.state.error, 'Respuesta inválida');
  });
  test(
    'auditoría fallida mantiene los indicadores clínicos y marca dato ausente',
    () async {
      user = admin;
      api.snapshot = data(
        patients: [patient()],
        auditError: 'Rechazo simulado',
      );
      await notifier.load();
      expect(notifier.state.summary!.monitoredPatients, 1);
      expect(notifier.state.summary!.auditMovements, isNull);
      expect(notifier.state.data!.auditError, 'Rechazo simulado');
    },
  );
  test(
    'sesión cambia mientras se consulta: no publica datos antiguos',
    () async {
      final gate = Completer<DashboardData>();
      api.loading = () => gate.future;
      final pending = notifier.load();
      user = doctor;
      gate.complete(data(patients: [patient()]));
      await pending;
      expect(notifier.state.data, isNull);
      expect(notifier.state.error, contains('sesión'));
    },
  );
  test('dispose antes de respuesta no modifica estado ni lanza', () async {
    final gate = Completer<DashboardData>();
    api.loading = () => gate.future;
    final pending = notifier.load();
    notifier.dispose();
    gate.complete(data());
    await expectLater(pending, completes);
  });
  test('permiso revocado borra resumen antes de consultar otra vez', () async {
    api.snapshot = data(patients: [patient()]);
    await notifier.load();
    user = null;
    await notifier.load();
    expect(notifier.state.data, isNull);
    expect(api.reads, 1);
  });
}
