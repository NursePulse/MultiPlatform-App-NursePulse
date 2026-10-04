import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/core/network/dio_client.dart';
import 'package:nurse_pulse_app/features/audit/application/audit_notifier.dart';
import 'package:nurse_pulse_app/features/dashboard/application/dashboard_notifier.dart';
import 'package:nurse_pulse_app/features/dashboard/infrastructure/dashboard_api.dart';
import 'package:nurse_pulse_app/features/report/application/report_notifier.dart';
import 'package:nurse_pulse_app/features/report/infrastructure/report_local_store.dart';

import '../audit_users/fixtures.dart' as wire;
import '../dashboard/fixtures.dart' as dash;
import '../notification/fixtures.dart' as alert;
import '../patient/fixtures.dart' show patientCommand;
import '../sbar/fixtures.dart' as sbar;
import 'fixtures.dart';

void main() {
  for (final failAudit in [false, true]) {
    test(
      'contratos reales: solo recursos existentes, auditoría ${failAudit ? 'rechazada' : 'válida'} y persistencia local',
      () async {
        final memory = MemoryReports();
        final paths = <String>[];
        final payloads = <Map<String, dynamic>>[];
        final dio = wire.mockDio((request) {
          if (request.method == 'POST' && request.path == '/audit-logs') {
            final body = Map<String, dynamic>.from(request.data as Map);
            payloads.add(body);
            if (failAudit) throw wire.httpFailure(503);
            return {
              ...body,
              'id': 100 + payloads.length,
              'performedAt': now.toUtc().toIso8601String(),
            };
          }
          return switch (request.path) {
            '/patients' => [
              {'id': 1, ...patientCommand().toJson()},
            ],
            '/vital-sign-records' => [dash.vitalJson()],
            '/handovers/patients/1' => [sbar.transferJson()],
            '/alerts' => [alert.alertJson()],
            '/audit-logs' => {
              'content': [
                {
                  ...wire.logJson(date: now.toUtc().toIso8601String()),
                  'entityType': 'CLINICAL_EVENT',
                  'actionType': 'CREATE',
                },
              ],
            },
            _ => throw StateError(
              'Ruta no autorizada por contrato ${request.method} ${request.path}',
            ),
          };
        }, paths: paths);
        final dashboard = dash.FakeDashboardApi();
        final container = ProviderContainer(
          overrides: [
            dioProvider.overrideWithValue(dio),
            reportLocalStoreProvider.overrideWithValue(memory.store),
            reportUserProvider.overrideWithValue(doctor),
            reportClockProvider.overrideWithValue(() => now),
            dashboardApiProvider.overrideWithValue(dashboard),
            dashboardUserProvider.overrideWithValue(doctor),
            auditUserProvider.overrideWithValue(doctor),
            // Reportes usa el AuditApi real; aquí no se reemplaza auditApiProvider.
          ],
        );
        addTearDown(container.dispose);
        final sub = container.listen(reportNotifierProvider, (_, _) {});
        addTearDown(sub.close);
        final dashSub = container.listen(dashboardNotifierProvider, (_, _) {});
        addTearDown(dashSub.close);
        final n = container.read(reportNotifierProvider.notifier);
        await n.load();
        await Future<void>.delayed(Duration.zero);
        final previousDashboard = container.read(
          dashboardNotifierProvider.notifier,
        );
        expect(paths, isEmpty);
        final result = await generate(n);
        expect(result.summary!.toJson(), {
          'patients': 1,
          'vitalSigns': 1,
          'clinicalEvents': 1,
          'sbarTransfers': 1,
          'activeAlerts': 1,
          'criticalAlerts': 1,
          'auditLogs': 1,
        });
        expect(
          paths.where(
            (path) =>
                path.contains('/reports') ||
                path.contains('/clinical-events') ||
                path == 'GET /handovers',
          ),
          isEmpty,
        );
        expect(paths.where((path) => path.startsWith('POST ')), [
          'POST /audit-logs',
          'POST /audit-logs',
        ]);
        expect(payloads.map((body) => body['entityType']), [
          'AUDIT_LOG',
          'AUDIT_LOG',
        ]);
        expect(payloads.map((body) => body['actionType']), ['VIEW', 'UPDATE']);
        expect(
          payloads.every(
            (body) =>
                body['entityId'] == result.id &&
                body['performedBy'] == doctor.username,
          ),
          isTrue,
        );
        expect(payloads.first['metadata'], {
          'description': 'Generó reporte: Reporte ficticio',
          'source': 'frontend',
        });
        expect(n.state.warning, failAudit ? isNotNull : isNull);
        expect(memory.writes, 1);
        expect(
          container.read(dashboardNotifierProvider.notifier),
          isNot(same(previousDashboard)),
        );
        await n.load();
        expect(payloads, hasLength(2));
        expect(memory.writes, 1);
      },
    );
  }
  test(
    'generar sin abrir primero carga y conserva los reportes existentes',
    () async {
      final memory = MemoryReports();
      await memory.store.add(report(id: 'anterior'));
      final n = notifier(memory, Sources());
      addTearDown(n.dispose);
      await generate(n);
      expect(n.state.reports, hasLength(2));
      expect(n.state.reports.any((r) => r.id == 'anterior'), isTrue);
    },
  );
}
