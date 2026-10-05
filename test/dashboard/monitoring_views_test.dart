import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/core/network/dio_client.dart';
import 'package:nurse_pulse_app/features/patient/application/patient_detail.dart';
import 'package:nurse_pulse_app/features/patient/presentation/patient_monitoring_view.dart';

import '../notification/fixtures.dart' as alerts;
import '../patient/fixtures.dart';
import 'fixtures.dart';

Future<void> mount(
  WidgetTester tester,
  ProviderContainer container, {
  String id = '1',
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: PatientMonitoringView(patientId: id)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'paciente eliminado durante refresco oculta datos y no recarga historial',
    (tester) async {
      var missing = false;
      final paths = <String>[];
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(
            mockDio((request) {
              if (request.path == '/patients/1') {
                if (missing) throw httpFailure(404);
                return {'id': 1, ...patientCommand().toJson()};
              }
              return [];
            }, paths: paths),
          ),
          patientMonitoringRolesProvider.overrideWithValue(nurse.roles),
        ],
      );
      addTearDown(container.dispose);
      await mount(tester, container);
      expect(paths, hasLength(4));
      missing = true;
      await tester.runAsync(
        () => tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh(),
      );
      await tester.pumpAndSettle();
      expect(paths, hasLength(5));
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Signos vitales (0)'), findsNothing);
    },
  );

  testWidgets(
    'error de historial recupera solo sus lecturas y conserva la ficha',
    (tester) async {
      var failing = true;
      final paths = <String>[];
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(
            mockDio((request) {
              if (request.path == '/patients/1') {
                return {'id': 1, ...patientCommand().toJson()};
              }
              if (failing && request.path == '/alerts/patients/1') {
                throw httpFailure(503);
              }
              return [];
            }, paths: paths),
          ),
          patientMonitoringRolesProvider.overrideWithValue(nurse.roles),
        ],
      );
      addTearDown(container.dispose);
      await mount(tester, container);
      expect(find.textContaining('Diagnóstico:'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Reintentar'), 250);
      await tester.pumpAndSettle();
      expect(find.text('Reintentar'), findsOneWidget);
      failing = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Signos vitales (0)'), 250);
      expect(find.text('Signos vitales (0)'), findsOneWidget);
      expect(paths, hasLength(7));
      expect(paths.where((path) => path == 'GET /patients/1'), hasLength(1));
    },
  );

  testWidgets(
    'paciente 404 no consulta historial y reintento recupera detalle',
    (tester) async {
      var fails = true;
      final paths = <String>[];
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(
            mockDio((request) {
              if (request.path == '/patients/1') {
                if (fails) throw httpFailure(404);
                return {'id': 1, ...patientCommand().toJson()};
              }
              return [];
            }, paths: paths),
          ),
          patientMonitoringRolesProvider.overrideWithValue(nurse.roles),
        ],
      );
      addTearDown(container.dispose);
      await mount(tester, container);
      expect(paths, ['GET /patients/1']);
      expect(find.text('Reintentar'), findsOneWidget);
      fails = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Signos vitales (0)'), 250);
      expect(find.text('Signos vitales (0)'), findsOneWidget);
      expect(paths.where((p) => p.contains('/patients/1')), hasLength(5));
    },
  );

  for (final id in ['0', 'abc']) {
    testWidgets('pantalla ID inválido $id no consulta API', (tester) async {
      final paths = <String>[];
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(mockDio((_) => [], paths: paths)),
          patientMonitoringRolesProvider.overrideWithValue(nurse.roles),
        ],
      );
      addTearDown(container.dispose);
      await mount(tester, container, id: id);
      expect(paths, isEmpty);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  }

  testWidgets('sin permisos oculta ficha e historial, sin API', (tester) async {
    final paths = <String>[];
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(mockDio((_) => [], paths: paths)),
        patientMonitoringRolesProvider.overrideWithValue([]),
      ],
    );
    addTearDown(container.dispose);
    await mount(tester, container);
    expect(
      find.text(
        'No tienes permiso para consultar el seguimiento del paciente.',
      ),
      findsOneWidget,
    );
    expect(find.text('Signos vitales (0)'), findsNothing);
    expect(paths, isEmpty);
  });

  for (final actor in [nurse, doctor, admin]) {
    testWidgets(
      'monitoreo ${actor.primaryRole} conserva ficha y fechas desconocidas',
      (tester) async {
        tester.view.physicalSize = const Size(400, 2200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final paths = <String>[];
        final container = ProviderContainer(
          overrides: [
            dioProvider.overrideWithValue(
              mockDio(
                (request) => switch (request.path) {
                  '/patients/1' => {
                    'id': 1,
                    ...patientCommand(birth: DateTime(2020)).toJson(),
                  },
                  '/vital-sign-records/patients/1' => [vitalJson()],
                  '/clinical-events/patients/1' => [eventJson()],
                  '/alerts/patients/1' => [alerts.alertJson(date: null)],
                  _ => throw StateError('Endpoint inesperado ${request.path}'),
                },
                paths: paths,
              ),
            ),
            patientMonitoringRolesProvider.overrideWithValue(actor.roles),
          ],
        );
        addTearDown(container.dispose);
        await mount(tester, container, id: '001');
        expect(find.textContaining('Médico tratante:'), findsOneWidget);
        expect(find.text('Signos vitales (1)'), findsOneWidget);
        expect(find.text('Eventos clínicos (1)'), findsOneWidget);
        expect(find.text('Alertas (1)'), findsOneWidget);
        expect(find.text('Generada: sin información'), findsOneWidget);
        expect(
          find.text(
            actor == doctor ? 'Ver signos vitales' : 'Registrar signos vitales',
          ),
          findsOneWidget,
        );
        expect(paths, isNot(contains('GET /patients/001')));
        await tester.runAsync(
          () => tester
              .widget<RefreshIndicator>(find.byType(RefreshIndicator))
              .onRefresh(),
        );
        await tester.pumpAndSettle();
        expect(paths.where((p) => p == 'GET /patients/1'), hasLength(2));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'filtro inclusivo no filtra alertas ni riesgo último y persiste al refrescar',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final paths = <String>[];
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(
            mockDio(
              (request) => switch (request.path) {
                '/patients/1' => {'id': 1, ...patientCommand().toJson()},
                '/vital-sign-records/patients/1' => [
                  vitalJson(date: DateTime(2026, 10, 1)),
                  vitalJson(
                    id: '9',
                    risk: 'CRITICAL',
                    date: DateTime(2026, 10, 4),
                  ),
                ],
                '/clinical-events/patients/1' => [
                  eventJson(date: DateTime(2026, 10, 1, 23, 59)),
                  eventJson(id: '9', date: DateTime(2026, 10, 4)),
                ],
                '/alerts/patients/1' => [alerts.alertJson()],
                _ => throw StateError('Endpoint inesperado ${request.path}'),
              },
              paths: paths,
            ),
          ),
          patientMonitoringRolesProvider.overrideWithValue(nurse.roles),
          patientMonitoringClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      await mount(tester, container);
      await tester.tap(find.text('Filtrar signos y eventos'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '10/01/2026');
      await tester.enterText(fields.at(1), '10/01/2026');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Signos vitales (1)'), findsOneWidget);
      expect(find.text('Eventos clínicos (1)'), findsOneWidget);
      expect(find.text('Alertas (1)'), findsOneWidget);
      expect(find.text('Último riesgo registrado: Crítico'), findsOneWidget);
      expect(paths, hasLength(4));
      await tester.runAsync(
        () => tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh(),
      );
      await tester.pumpAndSettle();
      expect(find.text('Signos vitales (1)'), findsOneWidget);
      expect(paths, hasLength(8));
      await tester.tap(find.text('Ver todo'));
      await tester.pumpAndSettle();
      expect(find.text('Signos vitales (2)'), findsOneWidget);
      expect(find.text('Eventos clínicos (2)'), findsOneWidget);
      expect(paths, hasLength(8));
    },
  );
}
