import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/core/network/dio_client.dart';
import 'package:nurse_pulse_app/features/dashboard/application/dashboard_notifier.dart';
import 'package:nurse_pulse_app/features/patient/application/patient_detail.dart';

import '../notification/fixtures.dart' as alerts;
import '../patient/fixtures.dart';
import 'fixtures.dart';

void main() {
  for (final actor in [nurse, doctor, admin]) {
    test(
      'Dashboard ${actor.primaryRole}: contratos reales y auditoría autorizada',
      () async {
        final paths = <String>[];
        final dio = mockDio((request) {
          expect(request.method, 'GET');
          return switch (request.path) {
            '/patients' => [
              {'id': 1, ...patientCommand().toJson()},
            ],
            '/alerts' => [
              alerts.alertJson(date: null),
              alerts.alertJson(id: '10'),
            ],
            '/clinical-events' => [eventJson()],
            '/vital-sign-records' => [vitalJson()],
            '/audit-logs' => () {
              expect(actor, isNot(nurse));
              expect(request.queryParameters, {'page': 0, 'size': 100});
              return {
                'content': [
                  auditJson(id: '1', date: DateTime(2025)),
                  auditJson(),
                ],
                'totalElements': 300,
              };
            }(),
            _ => throw StateError('Endpoint inesperado: ${request.path}'),
          };
        }, paths: paths);
        final container = ProviderContainer(
          overrides: [
            dioProvider.overrideWithValue(dio),
            dashboardUserProvider.overrideWithValue(actor),
            dashboardClockProvider.overrideWithValue(() => now),
          ],
        );
        addTearDown(container.dispose);
        await container.read(dashboardNotifierProvider.notifier).load();
        final state = container.read(dashboardNotifierProvider);
        expect(state.error, isNull);
        expect(state.summary!.monitoredPatients, 1);
        expect(state.summary!.activeAlerts, 2);
        expect(state.data!.alerts.map((a) => a.id), ['10', '9']);
        expect(state.summary!.auditMovements, actor == nurse ? null : 2);
        if (actor != nurse) {
          expect(state.data!.audits!.map((a) => a.id), ['5', '1']);
        }
        expect(paths.toSet(), {
          'GET /patients',
          'GET /alerts',
          'GET /clinical-events',
          'GET /vital-sign-records',
          if (actor != nurse) 'GET /audit-logs',
        });
        expect(paths.length, actor == nurse ? 4 : 5);
      },
    );
  }

  for (final endpoint in [
    '/patients',
    '/alerts',
    '/clinical-events',
    '/vital-sign-records',
  ]) {
    test('falla $endpoint no publica indicadores inventados', () async {
      final dio = mockDio((request) {
        if (request.path == endpoint) throw httpFailure(503);
        return [];
      });
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(dio),
          dashboardUserProvider.overrideWithValue(nurse),
        ],
      );
      addTearDown(container.dispose);
      await container.read(dashboardNotifierProvider.notifier).load();
      expect(container.read(dashboardNotifierProvider).summary, isNull);
      expect(container.read(dashboardNotifierProvider).error, isNotNull);
    });
  }

  for (final code in [403, 503]) {
    test(
      'auditoría $code permite mostrar datos clínicos con error parcial',
      () async {
        final dio = mockDio((request) {
          if (request.path == '/audit-logs') throw httpFailure(code);
          return [];
        });
        final container = ProviderContainer(
          overrides: [
            dioProvider.overrideWithValue(dio),
            dashboardUserProvider.overrideWithValue(admin),
          ],
        );
        addTearDown(container.dispose);
        await container.read(dashboardNotifierProvider.notifier).load();
        final state = container.read(dashboardNotifierProvider);
        expect(state.error, isNull);
        expect(state.summary!.monitoredPatients, 0);
        expect(state.summary!.auditMovements, isNull);
        expect(state.data!.auditError, isNotNull);
      },
    );
  }

  for (final id in ['', '0', '-1', '1.5', '1e2', 'abc']) {
    test('monitoreo ID inválido "$id": ninguna consulta', () async {
      final paths = <String>[];
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(mockDio((_) => [], paths: paths)),
          patientMonitoringRolesProvider.overrideWithValue(nurse.roles),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(patientDetailProvider(id).future),
        throwsFormatException,
      );
      await expectLater(
        container.read(patientHistoryProvider(id).future),
        throwsFormatException,
      );
      expect(paths, isEmpty);
    });
  }

  for (final roles in [
    <String>[],
    ['ROLE_UNKNOWN'],
  ]) {
    test('monitoreo sin permiso $roles: ninguna consulta', () async {
      final paths = <String>[];
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(mockDio((_) => [], paths: paths)),
          patientMonitoringRolesProvider.overrideWithValue(roles),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(patientDetailProvider('1').future),
        throwsFormatException,
      );
      await expectLater(
        container.read(patientHistoryProvider('1').future),
        throwsFormatException,
      );
      expect(paths, isEmpty);
    });
  }

  test(
    'monitoreo normaliza ID, consulta solo al paciente y ordena fechas reales',
    () async {
      final paths = <String>[];
      final dio = mockDio(
        (request) => switch (request.path) {
          '/patients/1' => {'id': 1, ...patientCommand().toJson()},
          '/vital-sign-records/patients/1' => [
            vitalJson(id: '1', date: DateTime(2025)),
            vitalJson(),
          ],
          '/clinical-events/patients/1' => [
            eventJson(id: '1', date: DateTime(2025)),
            eventJson(),
          ],
          '/alerts/patients/1' => [
            alerts.alertJson(date: null),
            alerts.alertJson(id: '10'),
          ],
          _ => throw StateError('Endpoint inesperado: ${request.path}'),
        },
        paths: paths,
      );
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(dio),
          patientMonitoringRolesProvider.overrideWithValue(doctor.roles),
        ],
      );
      addTearDown(container.dispose);
      expect(
        (await container.read(patientDetailProvider(' 001 ').future)).id,
        '1',
      );
      final history = await container.read(
        patientHistoryProvider(' 001 ').future,
      );
      expect(history.vitals.map((v) => v.id), ['8', '1']);
      expect(history.events.map((e) => e.id), ['7', '1']);
      expect(history.alerts.map((a) => a.id), ['10', '9']);
      expect(paths.toSet(), {
        'GET /patients/1',
        'GET /vital-sign-records/patients/1',
        'GET /clinical-events/patients/1',
        'GET /alerts/patients/1',
      });
    },
  );

  test('detalle rechaza una respuesta de otro paciente', () async {
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(
          mockDio((_) => {'id': 2, ...patientCommand().toJson()}),
        ),
        patientMonitoringRolesProvider.overrideWithValue(nurse.roles),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(patientDetailProvider('1').future),
      throwsFormatException,
    );
  });

  for (final endpoint in [
    '/vital-sign-records/patients/1',
    '/clinical-events/patients/1',
    '/alerts/patients/1',
  ]) {
    test('historial rechaza datos de otro paciente en $endpoint', () async {
      final dio = mockDio((request) {
        if (request.path != endpoint) return [];
        return switch (endpoint) {
          '/vital-sign-records/patients/1' => [vitalJson(patientId: '2')],
          '/clinical-events/patients/1' => [eventJson(patientId: '2')],
          _ => [alerts.alertJson(patientId: '2')],
        };
      });
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(dio),
          patientMonitoringRolesProvider.overrideWithValue(nurse.roles),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(patientHistoryProvider('1').future),
        throwsFormatException,
      );
    });
  }

  test(
    'historial falla y permite recuperar la lectura sin escrituras',
    () async {
      var failing = true;
      final paths = <String>[];
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(
            mockDio((request) {
              if (failing && request.path.startsWith('/alerts/')) {
                throw httpFailure(503);
              }
              return [];
            }, paths: paths),
          ),
          patientMonitoringRolesProvider.overrideWithValue(nurse.roles),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(patientHistoryProvider('1'), (_, _) {});
      addTearDown(sub.close);
      await expectLater(
        container.read(patientHistoryProvider('1').future),
        throwsA(anything),
      );
      failing = false;
      container.invalidate(patientHistoryProvider('1'));
      expect(
        (await container.read(patientHistoryProvider('1').future)).alerts,
        isEmpty,
      );
      expect(paths.length, 6);
      expect(paths.every((path) => path.startsWith('GET ')), isTrue);
    },
  );
}
