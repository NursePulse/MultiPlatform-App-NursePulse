import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/core/network/dio_client.dart';
import 'package:nurse_pulse_app/features/dashboard/application/dashboard_notifier.dart';
import 'package:nurse_pulse_app/features/dashboard/infrastructure/dashboard_api.dart';
import 'package:nurse_pulse_app/features/iam/application/users_notifier.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/patient/application/patient_notifier.dart';
import 'package:nurse_pulse_app/features/sbar/application/sbar_notifier.dart';

import '../dashboard/fixtures.dart' show FakeDashboardApi;
import 'fixtures.dart';

void main() {
  test('un cambio confirmado actualiza médicos, receptores SBAR y Dashboard sin repetir escritura', () async {
    var role = kRoleNurse;
    final paths = <String>[];
    final dio = mockDio((request) {
      if (request.path == '/users/2/roles' && request.method == 'PATCH') {
        expect(request.data, {
          'roles': [kRoleDoctor],
        });
        role = kRoleDoctor;
        return userJson(role: role);
      }
      if (request.path == '/users/2') return userJson(role: role);
      if (request.path == '/users') {
        return [
          userJson(role: role),
          userJson(id: '4', role: kRoleAdmin, username: 'admin.test'),
        ];
      }
      throw StateError('Consulta inesperada ${request.method} ${request.path}');
    }, paths: paths);
    final dashboard = FakeDashboardApi();
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        userManagementActorProvider.overrideWithValue(admin),
        sbarUserProvider.overrideWithValue(doctor),
        dashboardUserProvider.overrideWithValue(admin),
        dashboardApiProvider.overrideWithValue(dashboard),
      ],
    );
    addTearDown(container.dispose);
    final subs = [
      container.listen(patientDoctorsProvider, (_, _) {}),
      container.listen(sbarReceiversProvider, (_, _) {}),
      container.listen(dashboardNotifierProvider, (_, _) {}),
      container.listen(usersNotifierProvider, (_, _) {}),
    ];
    for (final sub in subs) {
      addTearDown(sub.close);
    }
    expect(await container.read(patientDoctorsProvider.future), isEmpty);
    await container.read(sbarUsersProvider.future);
    expect(
      container.read(sbarReceiversProvider).requireValue.map((u) => u.id),
      ['2'],
    );
    final notifier = container.read(usersNotifierProvider.notifier);
    await notifier.load();
    await Future<void>.delayed(Duration.zero);
    final previous = container.read(dashboardNotifierProvider.notifier);
    await notifier.updateRoles('2', [kRoleDoctor]);
    expect(await container.read(patientDoctorsProvider.future), [
      user().displayName,
    ]);
    await container.read(sbarUsersProvider.future);
    expect(container.read(sbarReceiversProvider).requireValue, isEmpty);
    expect(
      container.read(dashboardNotifierProvider.notifier),
      isNot(same(previous)),
    );
    await Future<void>.delayed(Duration.zero);
    expect(dashboard.reads, 2);
    expect(paths.where((p) => p.startsWith('PATCH ')), [
      'PATCH /users/2/roles',
    ]);
    expect(paths.where((p) => p.startsWith('POST ')), isEmpty);
    expect(paths.where((p) => p == 'GET /roles'), isEmpty);
  });
}
