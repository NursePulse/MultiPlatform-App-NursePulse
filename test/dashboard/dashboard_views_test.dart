import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nurse_pulse_app/features/dashboard/application/dashboard_notifier.dart';
import 'package:nurse_pulse_app/features/dashboard/infrastructure/dashboard_api.dart';
import 'package:nurse_pulse_app/features/dashboard/presentation/dashboard_view.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';

import '../notification/fixtures.dart' as alerts;
import 'fixtures.dart';

Future<void> mount(
  WidgetTester tester,
  FakeDashboardApi api, {
  User? user = nurse,
  double scale = 1,
}) async {
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(path: '/dashboard', builder: (_, _) => const DashboardView()),
      for (final path in [
        '/patients',
        '/vital-signs',
        '/clinical-events',
        '/sbar',
        '/alerts',
        '/reports',
        '/audit',
        '/patients/1/monitoring',
      ])
        GoRoute(
          path: path,
          builder: (_, _) => Scaffold(body: Text('Destino $path')),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardApiProvider.overrideWithValue(api),
        dashboardUserProvider.overrideWithValue(user),
        dashboardClockProvider.overrideWithValue(() => now),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'última actualización muestra auditoría real aunque alerta sea más nueva',
    (tester) async {
      final api = FakeDashboardApi()
        ..snapshot = data(
          audits: [audit(date: DateTime(2026, 10, 2, 9))],
          alerts: [
            alerts.alert(date: DateTime(2026, 10, 3, 20).toIso8601String()),
          ],
        );
      await mount(tester, api, user: admin);
      expect(
        find.text('Última actualización: 02/10/2026 09:00'),
        findsOneWidget,
      );
      expect(find.text('Última actualización: 04/10/2026 12:00'), findsNothing);
    },
  );

  testWidgets('sin auditoría, última actualización muestra triggeredAt real', (
    tester,
  ) async {
    final api = FakeDashboardApi()
      ..snapshot = data(
        alerts: [
          alerts.alert(date: DateTime(2026, 10, 3, 20).toIso8601String()),
        ],
      );
    await mount(tester, api);
    expect(find.text('Última actualización: 03/10/2026 20:00'), findsOneWidget);
  });

  testWidgets('Dashboard vacío muestra ceros reales y permite refrescar', (
    tester,
  ) async {
    final api = FakeDashboardApi();
    await mount(tester, api);
    expect(find.text('0'), findsNWidgets(7));
    await tester.scrollUntilVisible(
      find.text('No hay pacientes registrados.'),
      250,
      scrollable: find.descendant(
        of: find.byType(RefreshIndicator),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('No hay pacientes registrados.'), findsOneWidget);
    await tester.runAsync(
      () => tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh(),
    );
    await tester.pumpAndSettle();
    expect(api.reads, 2);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 400.0, 800.0]) {
    testWidgets('Dashboard ancho $width y texto al 200% sin desbordamiento', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(
        tester,
        FakeDashboardApi()
          ..snapshot = data(
            patients: [patient()],
            alerts: [alerts.alert(date: null)],
          ),
        user: admin,
        scale: 2,
      );
      for (var i = 0; i < 12; i++) {
        await tester.drag(
          find.descendant(
            of: find.byType(RefreshIndicator),
            matching: find.byType(ListView),
          ),
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  for (final actor in [nurse, doctor, admin]) {
    testWidgets('accesos y auditoría visibles por rol ${actor.primaryRole}', (
      tester,
    ) async {
      final api = FakeDashboardApi()..snapshot = data(audits: []);
      tester.view.physicalSize = const Size(800, 2500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, api, user: actor);
      await tester.scrollUntilVisible(
        find.text('Accesos rápidos'),
        350,
        scrollable: find.descendant(
          of: find.byType(RefreshIndicator),
          matching: find.byType(Scrollable),
        ),
      );
      expect(api.includeAudit, actor != nurse);
      expect(
        find.byKey(const ValueKey('dashboard-/reports')),
        actor == nurse ? findsNothing : findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dashboard-/audit')),
        actor == admin ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const ValueKey('dashboard-/sbar')),
        actor == nurse ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const ValueKey('dashboard-/vital-signs')),
        actor == nurse ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Auditoría reciente'),
        actor == admin ? findsOneWidget : findsNothing,
      );
      final destination = actor == admin ? '/reports' : '/patients';
      final action = find.byKey(ValueKey('dashboard-$destination'));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('Destino $destination'), findsOneWidget);
    });
  }

  for (final actor in [
    null,
    const User(id: '1', username: 'unknown.test', roles: ['ROLE_UNKNOWN']),
  ]) {
    testWidgets(
      'sin acceso clínico no expone indicadores ni consulta API ${actor?.username}',
      (tester) async {
        final api = FakeDashboardApi()..snapshot = data(patients: [patient()]);
        await mount(tester, api, user: actor);
        expect(api.reads, 0);
        expect(
          find.text('No tienes permiso para consultar el Dashboard.'),
          findsOneWidget,
        );
        expect(find.text('Pacientes monitoreados'), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);
      },
    );
  }

  testWidgets('fallo inicial y reintento recuperan Dashboard', (tester) async {
    final api = FakeDashboardApi()..failure = httpFailure(503);
    await mount(tester, api);
    expect(find.text('Pacientes monitoreados'), findsNothing);
    api.failure = null;
    await tester.tap(find.byKey(const ValueKey('dashboard-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Pacientes monitoreados'), findsOneWidget);
    expect(api.reads, 2);
  });

  testWidgets(
    'fallo al refrescar conserva indicadores y advierte consulta anterior',
    (tester) async {
      final api = FakeDashboardApi()..snapshot = data(patients: [patient()]);
      await mount(tester, api);
      api.failure = httpFailure(503);
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(
        find.text('Se muestran los datos de la última consulta completada.'),
        findsOneWidget,
      );
      expect(find.text('Pacientes monitoreados'), findsOneWidget);
      expect(
        find.text('Última actualización: 04/10/2026 12:00'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'error parcial de auditoría presenta valor desconocido y reintento',
    (tester) async {
      final api = FakeDashboardApi()
        ..snapshot = data(auditError: 'Error simulado');
      await mount(tester, api, user: admin);
      expect(find.text('—'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('dashboard-audit-retry')),
        300,
        scrollable: find.descendant(
          of: find.byType(RefreshIndicator),
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        find.text('No se pudo cargar la auditoría: Error simulado'),
        findsOneWidget,
      );
      api.snapshot = data(audits: [audit()]);
      await tester.tap(find.byKey(const ValueKey('dashboard-audit-retry')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Pacientes monitoreados'),
        -300,
        scrollable: find.descendant(
          of: find.byType(RefreshIndicator),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('—'), findsNothing);
      expect(api.reads, 2);
    },
  );

  testWidgets('solo cinco pacientes y alertas activas; navegación por ID', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FakeDashboardApi()
      ..snapshot = data(
        patients: [for (var id = 1; id <= 6; id++) patient(id: '$id')],
        alerts: [
          alerts.alert(status: 'CLOSED'),
          for (var id = 10; id <= 15; id++) alerts.alert(id: '$id', date: null),
        ],
      );
    await mount(tester, api);
    final patientTiles = find.byType(ListTile);
    await tester.scrollUntilVisible(
      patientTiles.first,
      300,
      scrollable: find.descendant(
        of: find.byType(RefreshIndicator),
        matching: find.byType(Scrollable),
      ),
    );
    expect(patientTiles, findsNWidgets(5));
    await tester.tap(patientTiles.first);
    await tester.pumpAndSettle();
    expect(find.text('Destino /patients/1/monitoring'), findsOneWidget);
    await mount(tester, api);
    await tester.scrollUntilVisible(
      find.text('Alertas activas recientes'),
      300,
      scrollable: find.descendant(
        of: find.byType(RefreshIndicator),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Generada: sin información'), findsNWidgets(5));
    expect(find.text('Cerrada'), findsNothing);
  });
}
