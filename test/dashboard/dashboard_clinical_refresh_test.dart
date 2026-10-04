import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/core/network/dio_client.dart';
import 'package:nurse_pulse_app/features/clinical_event/application/clinical_event_notifier.dart';
import 'package:nurse_pulse_app/features/clinical_event/domain/clinical_event.dart';
import 'package:nurse_pulse_app/features/dashboard/application/dashboard_notifier.dart';
import 'package:nurse_pulse_app/features/patient/application/patient_detail.dart';
import 'package:nurse_pulse_app/features/sbar/application/sbar_notifier.dart';
import 'package:nurse_pulse_app/features/vital_sign/application/vital_sign_notifier.dart';
import 'package:nurse_pulse_app/features/vital_sign/domain/vital_sign.dart';

import '../patient/fixtures.dart';
import '../sbar/fixtures.dart' as sbar;
import 'fixtures.dart';

void main() {
  for (final source in ['event', 'vital', 'sbar']) {
    test(
      '$source confirmado refresca Dashboard incluso si falla auditoría',
      () async {
        final paths = <String>[];
        Map<String, dynamic>? saved;
        final dio = mockDio((request) {
          if (request.method == 'POST') {
            if (request.path == '/audit-logs') throw httpFailure(503);
            saved = switch (source) {
              'event' => eventJson(),
              'vital' => vitalJson(),
              _ => sbar.transferJson(),
            };
            return saved;
          }
          return switch (request.path) {
            '/patients/1' => {'id': 1, ...patientCommand().toJson()},
            '/patients' => [
              {'id': 1, ...patientCommand().toJson()},
            ],
            '/clinical-events' || '/clinical-events/patients/1' => [
              if (source == 'event' && saved != null) saved,
            ],
            '/vital-sign-records' || '/vital-sign-records/patients/1' => [
              if (source == 'vital' && saved != null) saved,
            ],
            '/users' => [
              {'id': 3, 'username': 'receiver.test', 'roles': nurse.roles},
            ],
            _ => [],
          };
        }, paths: paths);
        final container = ProviderContainer(
          overrides: [
            dioProvider.overrideWithValue(dio),
            dashboardUserProvider.overrideWithValue(nurse),
            dashboardClockProvider.overrideWithValue(() => now),
            patientMonitoringRolesProvider.overrideWithValue(nurse.roles),
            clinicalEventUserProvider.overrideWithValue(nurse),
            vitalSignUserProvider.overrideWithValue(nurse),
            sbarUserProvider.overrideWithValue(nurse),
          ],
        );
        addTearDown(container.dispose);
        final dashSub = container.listen(dashboardNotifierProvider, (_, _) {});
        final historySub = container.listen(
          patientHistoryProvider('1'),
          (_, _) {},
        );
        addTearDown(dashSub.close);
        addTearDown(historySub.close);
        await container.read(dashboardNotifierProvider.notifier).load();
        await container.read(patientHistoryProvider('1').future);
        final previous = container.read(dashboardNotifierProvider.notifier);
        if (source == 'event') {
          await container
              .read(clinicalEventNotifierProvider.notifier)
              .register(
                const RegisterClinicalEventCommand(
                  patientId: '1',
                  eventType: 'OBSERVATION',
                  severity: 'LOW',
                  title: 'Evento ficticio',
                  description: 'Descripción ficticia de prueba',
                ),
              );
          expect(
            container.read(clinicalEventNotifierProvider).warning,
            isNotNull,
          );
        } else if (source == 'vital') {
          await container
              .read(vitalSignNotifierProvider.notifier)
              .record(
                const RecordVitalSignCommand(
                  patientId: '1',
                  nurseId: '2',
                  heartRate: 80,
                  respiratoryRate: 16,
                  systolicPressure: 120,
                  diastolicPressure: 80,
                  oxygenSaturation: 98,
                  temperature: 36.5,
                ),
              );
          expect(container.read(vitalSignNotifierProvider).warning, isNotNull);
        } else {
          await container
              .read(sbarNotifierProvider.notifier)
              .register(sbar.command());
          expect(container.read(sbarNotifierProvider).warning, isNotNull);
        }
        await container.read(dashboardNotifierProvider.notifier).load();
        expect(
          container.read(dashboardNotifierProvider.notifier),
          isNot(same(previous)),
        );
        final summary = container.read(dashboardNotifierProvider).summary!;
        expect(summary.clinicalEventsToday, source == 'event' ? 1 : 0);
        expect(summary.inspectionsThisMonth, source == 'vital' ? 1 : 0);
        final history = await container.read(
          patientHistoryProvider('1').future,
        );
        expect(history.events.length, source == 'event' ? 1 : 0);
        expect(history.vitals.length, source == 'vital' ? 1 : 0);
        expect(
          paths.where((p) => p.startsWith('POST ') && p != 'POST /audit-logs'),
          hasLength(1),
        );
      },
    );
  }
}
