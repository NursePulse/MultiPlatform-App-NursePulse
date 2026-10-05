import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/core/network/dio_client.dart';
import 'package:nurse_pulse_app/core/storage/secure_store.dart';
import 'package:nurse_pulse_app/features/dashboard/application/dashboard_notifier.dart';
import 'package:nurse_pulse_app/features/notification/application/alert_notifier.dart';
import 'package:nurse_pulse_app/features/notification/domain/alert.dart';
import 'package:nurse_pulse_app/features/patient/application/patient_detail.dart';
import 'package:nurse_pulse_app/features/patient/application/patient_notifier.dart';
import 'package:nurse_pulse_app/features/patient/domain/patient_rules.dart';

import '../notification/fixtures.dart' as alerts;
import '../patient/fixtures.dart';
import 'fixtures.dart';

class EmptyStore extends SecureStore {
  @override
  Future<String?> readToken() async => null;
  @override
  Future<Map<String, dynamic>?> readUser() async => null;
}

void main() {
  test(
    'crear, editar y dar alta actualizan Dashboard y detalle sin repetir PUT',
    () async {
      Map<String, dynamic>? saved;
      final paths = <String>[];
      final dio = mockDio((request) {
        if (request.method == 'POST' && request.path == '/audit-logs') {
          throw httpFailure(503);
        }
        if (request.method == 'POST' && request.path == '/patients' ||
            request.method == 'PUT' && request.path == '/patients/1') {
          saved = {'id': 1, ...request.data as Map<String, dynamic>};
          return saved;
        }
        if (request.path == '/patients/1') return saved;
        if (request.path == '/patients') return [?saved];
        return [];
      }, paths: paths);
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(dio),
          secureStoreProvider.overrideWithValue(EmptyStore()),
          dashboardUserProvider.overrideWithValue(nurse),
          dashboardClockProvider.overrideWithValue(() => now),
          patientPermissionsProvider.overrideWithValue(
            PatientPermissions(nurse.roles),
          ),
          patientMonitoringRolesProvider.overrideWithValue(nurse.roles),
        ],
      );
      addTearDown(container.dispose);
      final dashSub = container.listen(dashboardNotifierProvider, (_, _) {});
      addTearDown(dashSub.close);
      await container.read(dashboardNotifierProvider.notifier).load();
      expect(
        container.read(dashboardNotifierProvider).summary!.monitoredPatients,
        0,
      );
      final notifier = container.read(patientNotifierProvider.notifier);
      await notifier.create(patientCommand());
      await container.read(dashboardNotifierProvider.notifier).load();
      expect(
        container.read(dashboardNotifierProvider).summary!.monitoredPatients,
        1,
      );
      final detailSub = container.listen(patientDetailProvider('1'), (_, _) {});
      addTearDown(detailSub.close);
      expect(
        (await container.read(patientDetailProvider('1').future)).firstName,
        'Ana',
      );
      await notifier.update('1', patientCommand(first: 'Cambio ficticio'));
      expect(
        (await container.read(patientDetailProvider('1').future)).firstName,
        'Cambio ficticio',
      );
      await container.read(dashboardNotifierProvider.notifier).load();
      expect(
        container
            .read(dashboardNotifierProvider)
            .data!
            .patients
            .single
            .firstName,
        'Cambio ficticio',
      );
      await notifier.discharge('1');
      await container.read(dashboardNotifierProvider.notifier).load();
      expect(
        container.read(dashboardNotifierProvider).summary!.monitoredPatients,
        0,
      );
      await notifier.discharge('1');
      expect(paths.where((p) => p == 'POST /patients'), hasLength(1));
      expect(paths.where((p) => p == 'PUT /patients/1'), hasLength(2));
    },
  );

  test(
    'eliminar paciente actualiza Dashboard y el detalle pasa a 404',
    () async {
      var exists = true;
      final paths = <String>[];
      final saved = {'id': 1, ...patientCommand().toJson()};
      final dio = mockDio((request) {
        if (request.method == 'DELETE') {
          exists = false;
          return null;
        }
        if (request.path == '/patients/1') {
          if (!exists) throw httpFailure(404);
          return saved;
        }
        if (request.path == '/patients') return [if (exists) saved];
        return [];
      }, paths: paths);
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(dio),
          dashboardUserProvider.overrideWithValue(admin),
          patientPermissionsProvider.overrideWithValue(
            PatientPermissions(admin.roles),
          ),
          patientMonitoringRolesProvider.overrideWithValue(admin.roles),
        ],
      );
      addTearDown(container.dispose);
      final dashSub = container.listen(dashboardNotifierProvider, (_, _) {});
      final detailSub = container.listen(patientDetailProvider('1'), (_, _) {});
      addTearDown(dashSub.close);
      addTearDown(detailSub.close);
      await container.read(dashboardNotifierProvider.notifier).load();
      await container.read(patientDetailProvider('1').future);
      await container.read(patientNotifierProvider.notifier).delete('1');
      await container.read(dashboardNotifierProvider.notifier).load();
      expect(
        container.read(dashboardNotifierProvider).summary!.monitoredPatients,
        0,
      );
      await expectLater(
        container.read(patientDetailProvider('1').future),
        throwsA(anything),
      );
      expect(paths.where((p) => p == 'DELETE /patients/1'), hasLength(1));
    },
  );

  for (final auditFails in [false, true]) {
    test(
      'atender/cerrar refresca Dashboard e historial; auditoría falla=$auditFails',
      () async {
        var status = 'OPEN';
        final paths = <String>[];
        final dio = mockDio((request) {
          if (request.method == 'PATCH') {
            status = request.path.endsWith('attend') ? 'ATTENDED' : 'CLOSED';
            return alerts.alertJson(status: status);
          }
          if (request.method == 'POST' && request.path == '/audit-logs') {
            if (auditFails) throw httpFailure(503);
            return auditJson();
          }
          return switch (request.path) {
            '/patients' => [
              {'id': 1, ...patientCommand().toJson()},
            ],
            '/alerts/9' => alerts.alertJson(status: status),
            '/alerts' ||
            '/alerts/patients/1' => [alerts.alertJson(status: status)],
            _ => [],
          };
        }, paths: paths);
        final container = ProviderContainer(
          overrides: [
            dioProvider.overrideWithValue(dio),
            dashboardUserProvider.overrideWithValue(doctor),
            alertUserProvider.overrideWithValue(doctor),
            patientMonitoringRolesProvider.overrideWithValue(doctor.roles),
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
        expect(
          container.read(dashboardNotifierProvider).summary!.activeAlerts,
          1,
        );
        final notifier = container.read(alertNotifierProvider.notifier);
        await notifier.attend('9');
        await container.read(dashboardNotifierProvider.notifier).load();
        expect(
          container.read(dashboardNotifierProvider).summary!.activeAlerts,
          1,
        );
        expect(
          (await container.read(patientHistoryProvider('1').future))
              .alerts
              .single
              .status
              .wireValue,
          'ATTENDED',
        );
        await notifier.close('9');
        await container.read(dashboardNotifierProvider.notifier).load();
        expect(
          container.read(dashboardNotifierProvider).summary!.activeAlerts,
          0,
        );
        expect(
          (await container.read(patientHistoryProvider('1').future))
              .alerts
              .single
              .status
              .wireValue,
          'CLOSED',
        );
        await notifier.close('9');
        expect(paths.where((p) => p == 'PATCH /alerts/9/attend'), hasLength(1));
        expect(paths.where((p) => p == 'PATCH /alerts/9/close'), hasLength(1));
        expect(
          container.read(alertNotifierProvider).warning == null,
          !auditFails,
        );
      },
    );
  }
}
