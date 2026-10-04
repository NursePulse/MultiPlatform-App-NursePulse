import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/core/network/dio_client.dart';
import 'package:nurse_pulse_app/core/storage/secure_store.dart';
import 'package:nurse_pulse_app/features/clinical_event/application/clinical_event_notifier.dart';
import 'package:nurse_pulse_app/features/clinical_event/domain/clinical_event.dart';
import 'package:nurse_pulse_app/features/dashboard/application/dashboard_notifier.dart';
import 'package:nurse_pulse_app/features/iam/application/auth_notifier.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/notification/application/alert_notifier.dart';
import 'package:nurse_pulse_app/features/patient/application/patient_detail.dart';
import 'package:nurse_pulse_app/features/patient/application/patient_notifier.dart';
import 'package:nurse_pulse_app/features/sbar/application/sbar_notifier.dart';
import 'package:nurse_pulse_app/features/vital_sign/application/vital_sign_notifier.dart';
import 'package:nurse_pulse_app/features/vital_sign/domain/vital_sign.dart';

import '../dashboard/fixtures.dart' as dash;
import '../notification/fixtures.dart' as alerts;
import '../patient/fixtures.dart' show patientCommand;
import '../sbar/fixtures.dart' as sbar;

class SessionStore extends SecureStore {
  SessionStore({this.actor = dash.nurse});
  final User actor;
  @override
  Future<String?> readToken() async => 'fictitious-session';
  @override
  Future<Map<String, dynamic>?> readUser() async => actor.toJson();
  @override
  Future<void> clearSession() async {}
  @override
  Future<void> clearViewMode() async {}
  @override
  Future<void> saveViewMode(String mode) async {}
  @override
  Future<String?> readSubscriptionPlan() async => null;
}

class TestAuth extends AuthNotifier {
  TestAuth(super.ref);
  void replace(User actor) => state = AuthState(
    user: actor,
    token: 'another-fictitious-session',
    restoring: false,
  );
}

Dio simulatedDio(
  FutureOr<Object?> Function(RequestOptions) reply,
  List<String> calls,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        calls.add('${options.method} ${options.path}');
        try {
          handler.resolve(
            Response(
              requestOptions: options,
              data: await reply(options),
              statusCode: options.method == 'POST' ? 201 : 200,
            ),
          );
        } catch (error) {
          handler.reject(DioException(requestOptions: options, error: error));
        }
      },
    ),
  );
  addTearDown(dio.close);
  return dio;
}

Object? clinicalReply(RequestOptions request) => switch (request.path) {
  '/patients' => [
    {'id': 1, ...patientCommand().toJson()},
  ],
  '/patients/1' => {'id': 1, ...patientCommand().toJson()},
  '/vital-sign-records' ||
  '/vital-sign-records/patients/1' => [dash.vitalJson()],
  '/clinical-events' || '/clinical-events/patients/1' => [dash.eventJson()],
  '/alerts' || '/alerts/patients/1' => [alerts.alertJson()],
  '/handovers/patients/1' => [sbar.transferJson()],
  _ => [],
};

Future<ProviderContainer> sessionContainer(Dio dio) async {
  final container = ProviderContainer(
    overrides: [
      dioProvider.overrideWithValue(dio),
      secureStoreProvider.overrideWithValue(SessionStore()),
      authNotifierProvider.overrideWith(TestAuth.new),
    ],
  );
  addTearDown(container.dispose);
  container.read(authNotifierProvider);
  await Future<void>.delayed(Duration.zero);
  expect(container.read(authNotifierProvider).isAuthenticated, isTrue);
  return container;
}

void main() {
  for (final signOut in [false, true]) {
    test(
      'listas clínicas se vacían al ${signOut ? 'cerrar sesión' : 'cambiar a otra cuenta del mismo rol'}',
      () async {
        final calls = <String>[];
        final container = await sessionContainer(
          simulatedDio(clinicalReply, calls),
        );
        final patients = container.read(patientNotifierProvider.notifier);
        final vitals = container.read(vitalSignNotifierProvider.notifier);
        final events = container.read(clinicalEventNotifierProvider.notifier);
        final handovers = container.read(sbarNotifierProvider.notifier);
        final notifications = container.read(alertNotifierProvider.notifier);
        await Future.wait([
          patients.load(),
          vitals.load(),
          events.load(),
          handovers.load(),
          notifications.load(),
        ]);
        expect(container.read(patientNotifierProvider).patients, hasLength(1));
        expect(container.read(vitalSignNotifierProvider).records, hasLength(1));
        expect(
          container.read(clinicalEventNotifierProvider).events,
          hasLength(1),
        );
        expect(container.read(sbarNotifierProvider).transfers, hasLength(1));
        expect(container.read(alertNotifierProvider).alerts, hasLength(1));
        final before = calls.length;
        final auth = container.read(authNotifierProvider.notifier) as TestAuth;
        if (signOut) {
          await auth.signOut();
        } else {
          auth.replace(
            const User(
              id: '20',
              username: 'other-nurse.test',
              roles: [kRoleNurse],
            ),
          );
        }
        expect(container.read(patientNotifierProvider).patients, isEmpty);
        expect(container.read(vitalSignNotifierProvider).records, isEmpty);
        expect(container.read(clinicalEventNotifierProvider).events, isEmpty);
        expect(container.read(sbarNotifierProvider).transfers, isEmpty);
        expect(container.read(alertNotifierProvider).alerts, isEmpty);
        expect([
          patients.mounted,
          vitals.mounted,
          events.mounted,
          handovers.mounted,
          notifications.mounted,
        ], everyElement(isFalse));
        expect(calls.skip(before), isEmpty);
      },
    );
  }

  for (final source in ['patients', 'vitals', 'events', 'alerts', 'sbar']) {
    test('$source: respuesta tardía no repuebla otra sesión', () async {
      final gate = Completer<Object?>();
      final started = Completer<void>();
      final calls = <String>[];
      final target = switch (source) {
        'patients' || 'sbar' => '/patients',
        'vitals' => '/vital-sign-records',
        'events' => '/clinical-events',
        _ => '/alerts',
      };
      final container = await sessionContainer(
        simulatedDio((request) {
          if (request.path == target) {
            started.complete();
            return gate.future;
          }
          return clinicalReply(request);
        }, calls),
      );
      final pending = switch (source) {
        'patients' => container.read(patientNotifierProvider.notifier).load(),
        'vitals' => container.read(vitalSignNotifierProvider.notifier).load(),
        'events' =>
          container.read(clinicalEventNotifierProvider.notifier).load(),
        'sbar' => container.read(sbarNotifierProvider.notifier).load(),
        _ => container.read(alertNotifierProvider.notifier).load(),
      };
      await started.future;
      await container.read(authNotifierProvider.notifier).signOut();
      // Leer fuerza la reconstrucción aun sin una pantalla escuchando.
      container.read(patientNotifierProvider);
      container.read(vitalSignNotifierProvider);
      container.read(clinicalEventNotifierProvider);
      container.read(sbarNotifierProvider);
      container.read(alertNotifierProvider);
      gate.complete(clinicalReply(RequestOptions(path: target)));
      await pending;
      expect(container.read(patientNotifierProvider).patients, isEmpty);
      expect(container.read(vitalSignNotifierProvider).records, isEmpty);
      expect(container.read(clinicalEventNotifierProvider).events, isEmpty);
      expect(container.read(sbarNotifierProvider).transfers, isEmpty);
      expect(container.read(alertNotifierProvider).alerts, isEmpty);
      expect(calls, ['GET $target']);
    });
  }

  for (final source in ['vitals', 'events']) {
    test(
      '$source: cambio de sesión durante validación del paciente no hace POST',
      () async {
        final started = Completer<void>();
        final patientGate = Completer<Object?>();
        final calls = <String>[];
        final container = await sessionContainer(
          simulatedDio((request) {
            started.complete();
            return patientGate.future;
          }, calls),
        );
        final operation = source == 'vitals'
            ? container
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
                  )
            : container
                  .read(clinicalEventNotifierProvider.notifier)
                  .register(
                    const RegisterClinicalEventCommand(
                      patientId: '1',
                      eventType: 'OBSERVATION',
                      severity: 'LOW',
                      title: 'Observación ficticia',
                      description: 'Descripción ficticia de integración',
                    ),
                  );
        final rejected = expectLater(operation, throwsFormatException);
        await started.future;
        await container.read(authNotifierProvider.notifier).signOut();
        container.read(vitalSignNotifierProvider);
        container.read(clinicalEventNotifierProvider);
        patientGate.complete({'id': 1, ...patientCommand().toJson()});
        await rejected;
        expect(calls, ['GET /patients/1']);
      },
    );
  }

  test(
    'detalle e historial recargan cuando cambia la cuenta con el mismo rol',
    () async {
      final calls = <String>[];
      final container = await sessionContainer(
        simulatedDio(clinicalReply, calls),
      );
      final detailSub = container.listen(patientDetailProvider('1'), (_, _) {});
      final historySub = container.listen(
        patientHistoryProvider('1'),
        (_, _) {},
      );
      addTearDown(detailSub.close);
      addTearDown(historySub.close);
      final firstDetail = await container.read(
        patientDetailProvider('1').future,
      );
      final firstHistory = await container.read(
        patientHistoryProvider('1').future,
      );
      (container.read(authNotifierProvider.notifier) as TestAuth).replace(
        User(
          id: '20',
          username: 'other-nurse.test',
          roles: container.read(authNotifierProvider).user!.roles,
        ),
      );
      expect(
        await container.read(patientDetailProvider('1').future),
        isNot(same(firstDetail)),
      );
      expect(
        await container.read(patientHistoryProvider('1').future),
        isNot(same(firstHistory)),
      );
      expect(calls.where((c) => c == 'GET /patients/1'), hasLength(2));
      expect(calls.where((c) => c == 'GET /alerts/patients/1'), hasLength(2));
    },
  );

  test('sesión cerrada no consulta pacientes, signos ni Dashboard', () async {
    final calls = <String>[];
    final container = await sessionContainer(
      simulatedDio(clinicalReply, calls),
    );
    await container.read(authNotifierProvider.notifier).signOut();
    await container.read(patientNotifierProvider.notifier).load();
    await container.read(vitalSignNotifierProvider.notifier).load();
    await container.read(dashboardNotifierProvider.notifier).load();
    expect(calls, isEmpty);
    expect(container.read(patientNotifierProvider).error, contains('permiso'));
    expect(
      container.read(vitalSignNotifierProvider).error,
      contains('permiso'),
    );
  });
}
