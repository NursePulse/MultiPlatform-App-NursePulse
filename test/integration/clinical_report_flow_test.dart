import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/core/network/dio_client.dart';
import 'package:nurse_pulse_app/features/clinical_event/application/clinical_event_notifier.dart';
import 'package:nurse_pulse_app/features/clinical_event/domain/clinical_event.dart';
import 'package:nurse_pulse_app/features/dashboard/application/dashboard_notifier.dart';
import 'package:nurse_pulse_app/features/iam/application/auth_notifier.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/notification/application/alert_notifier.dart';
import 'package:nurse_pulse_app/features/patient/application/patient_detail.dart';
import 'package:nurse_pulse_app/features/patient/application/patient_notifier.dart';
import 'package:nurse_pulse_app/features/report/application/report_notifier.dart';
import 'package:nurse_pulse_app/features/report/domain/report.dart';
import 'package:nurse_pulse_app/features/report/infrastructure/report_local_store.dart';
import 'package:nurse_pulse_app/features/sbar/application/sbar_notifier.dart';
import 'package:nurse_pulse_app/features/vital_sign/application/vital_sign_notifier.dart';
import 'package:nurse_pulse_app/features/vital_sign/domain/vital_sign.dart';

import '../dashboard/fixtures.dart' as dash;
import '../notification/fixtures.dart' as alerts;
import '../patient/fixtures.dart' show patientCommand;
import '../reports/fixtures.dart' show MemoryReports;
import '../sbar/fixtures.dart' as sbar;
import 'session_isolation_test.dart' show SessionStore, simulatedDio;

void main() {
  for (final auditFails in [false, true]) {
    test(
      'flujo paciente → signos/evento → alertas/SBAR → reporte; auditoría falla=$auditFails',
      () async {
        Map<String, dynamic>? patient;
        final vitals = <Map<String, dynamic>>[];
        final events = <Map<String, dynamic>>[];
        final notifications = <Map<String, dynamic>>[];
        final handovers = <Map<String, dynamic>>[];
        final audits = <Map<String, dynamic>>[];
        final calls = <String>[];
        final storage = MemoryReports();
        final dio = simulatedDio((request) {
          final body = request.data is Map
              ? Map<String, dynamic>.from(request.data as Map)
              : <String, dynamic>{};
          if (request.method == 'POST') {
            switch (request.path) {
              case '/patients':
                patient = {'id': 1, ...body};
                return patient;
              case '/vital-sign-records':
                final saved = {
                  ...dash.vitalJson(date: dash.now),
                  'riskLevel': 'HIGH',
                  'nurseId': body['nurseId'],
                };
                vitals.add(saved);
                return saved;
              case '/clinical-events':
                final saved = {
                  ...dash.eventJson(date: dash.now),
                  ...body,
                  'registeredBy': dash.admin.username,
                };
                events.add(saved);
                return saved;
              case '/alerts':
                final saved = {
                  ...alerts.alertJson(
                    id: '${notifications.length + 1}',
                    date: dash.now.toUtc().toIso8601String(),
                  ),
                  ...body,
                };
                notifications.add(saved);
                return saved;
              case '/handovers':
                handovers.add({
                  ...sbar.transferJson(
                    date: dash.now.toUtc().toIso8601String(),
                  ),
                  ...body,
                });
                return 9; // Contrato real: ID y lectura posterior del detalle.
              case '/audit-logs':
                if (auditFails) throw dash.httpFailure(503);
                final saved = {
                  ...body,
                  'id': audits.length + 1,
                  'performedAt': dash.now.toUtc().toIso8601String(),
                };
                audits.add(saved);
                return saved;
              default:
                throw StateError('Escritura inesperada ${request.path}');
            }
          }
          if (request.method == 'PATCH') {
            final id = request.path.split('/')[2];
            final index = notifications.indexWhere((a) => '${a['id']}' == id);
            notifications[index] = {
              ...notifications[index],
              'status': request.path.endsWith('/attend')
                  ? 'ATTENDED'
                  : 'CLOSED',
            };
            return notifications[index];
          }
          if (request.method == 'PUT' && request.path == '/patients/1') {
            patient = {'id': 1, ...body};
            return patient;
          }
          return switch (request.path) {
            '/patients' => [?patient],
            '/patients/1' => patient,
            '/vital-sign-records' || '/vital-sign-records/patients/1' => vitals,
            '/clinical-events' || '/clinical-events/patients/1' => events,
            '/alerts' || '/alerts/patients/1' => notifications,
            '/alerts/1' => notifications.first,
            '/handovers/patients/1' => handovers,
            '/handovers/9' => handovers.single,
            '/audit-logs' => {'content': audits},
            '/users' => [
              {
                'id': 3,
                'username': 'receiver.test',
                'roles': [kRoleNurse],
              },
            ],
            _ => throw StateError('Lectura inesperada ${request.path}'),
          };
        }, calls);
        final container = ProviderContainer(
          overrides: [
            dioProvider.overrideWithValue(dio),
            secureStoreProvider.overrideWithValue(
              SessionStore(actor: dash.admin),
            ),
            reportLocalStoreProvider.overrideWithValue(storage.store),
            reportClockProvider.overrideWithValue(() => dash.now),
            dashboardClockProvider.overrideWithValue(() => dash.now),
          ],
        );
        addTearDown(container.dispose);
        container.read(authNotifierProvider);
        await Future<void>.delayed(Duration.zero);
        final dashboardSub = container.listen(
          dashboardNotifierProvider,
          (_, _) {},
        );
        addTearDown(dashboardSub.close);
        await container.read(dashboardNotifierProvider.notifier).load();
        expect(
          container.read(dashboardNotifierProvider).summary!.monitoredPatients,
          0,
        );
        await container
            .read(patientNotifierProvider.notifier)
            .create(patientCommand());
        await container
            .read(vitalSignNotifierProvider.notifier)
            .record(
              const RecordVitalSignCommand(
                patientId: '1',
                nurseId: '999',
                heartRate: 120,
                respiratoryRate: 24,
                systolicPressure: 140,
                diastolicPressure: 90,
                oxygenSaturation: 92,
                temperature: 38,
              ),
            );
        await container
            .read(clinicalEventNotifierProvider.notifier)
            .register(
              const RegisterClinicalEventCommand(
                patientId: '1',
                eventType: 'OBSERVATION',
                severity: 'CRITICAL',
                title: 'Evento ficticio crítico',
                description: 'Descripción ficticia de integración',
              ),
            );
        await container
            .read(sbarNotifierProvider.notifier)
            .register(sbar.command());
        expect(notifications, hasLength(2));
        final alertNotifier = container.read(alertNotifierProvider.notifier);
        await alertNotifier.attend('1');
        await alertNotifier.close('1');
        await alertNotifier.close('1');
        await container.read(dashboardNotifierProvider.notifier).load();
        final summary = container.read(dashboardNotifierProvider).summary!;
        expect(summary.monitoredPatients, 1);
        expect(summary.inspectionsThisMonth, 1);
        expect(summary.clinicalEventsToday, 1);
        expect(summary.activeAlerts, 1);
        expect(summary.criticalAlerts, 1);
        final historySub = container.listen(
          patientHistoryProvider('1'),
          (_, _) {},
        );
        addTearDown(historySub.close);
        final history = await container.read(
          patientHistoryProvider('1').future,
        );
        expect(history.vitals.single.nurseId, dash.admin.id);
        expect(history.events, hasLength(1));
        expect(history.alerts.where((a) => a.isActive), hasLength(1));
        final auditCountBefore = audits.length;
        final reportNotifier = container.read(reportNotifierProvider.notifier);
        await reportNotifier.load();
        final report = await reportNotifier.generate(
          type: ReportType.general,
          title: 'Reporte ficticio de integración',
          startDate: dash.now,
          endDate: dash.now,
        );
        expect(report.summary!.patients, 1);
        expect(report.summary!.vitalSigns, 1);
        expect(report.summary!.clinicalEvents, auditFails ? 0 : 1);
        expect(report.summary!.sbarTransfers, 1);
        expect(report.summary!.activeAlerts, 1);
        expect(report.summary!.criticalAlerts, 1);
        expect(report.summary!.auditLogs, auditCountBefore);
        expect(
          container.read(reportNotifierProvider).warning != null,
          auditFails,
        );
        expect(await storage.store.getAll(), hasLength(1));
        if (!auditFails) {
          expect(
            audits
                .skip(auditCountBefore)
                .map((a) => '${a['entityType']}/${a['actionType']}'),
            ['AUDIT_LOG/VIEW', 'AUDIT_LOG/UPDATE'],
          );
        }
        final writes = calls.where((c) => !c.startsWith('GET ')).toList();
        await reportNotifier.load();
        await container.read(dashboardNotifierProvider.notifier).load();
        container.invalidate(patientHistoryProvider('1'));
        await container.read(patientHistoryProvider('1').future);
        expect(calls.where((c) => !c.startsWith('GET ')), writes);
        for (final path in [
          '/patients',
          '/vital-sign-records',
          '/clinical-events',
          '/handovers',
        ]) {
          expect(calls.where((c) => c == 'POST $path'), hasLength(1));
        }
        expect(calls.where((c) => c == 'POST /alerts'), hasLength(2));
        expect(calls.where((c) => c == 'PATCH /alerts/1/close'), hasLength(1));
        expect(
          calls.any((c) => c.contains('/reports') || c == 'GET /handovers'),
          isFalse,
        );
        await container.read(patientNotifierProvider.notifier).discharge('1');
        await container.read(dashboardNotifierProvider.notifier).load();
        expect(
          container.read(dashboardNotifierProvider).summary!.monitoredPatients,
          0,
        );
        expect((await storage.store.getAll()).single.summary!.patients, 1);
      },
    );
  }
}
