import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/core/network/dio_client.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/patient/application/patient_detail.dart';
import 'package:nurse_pulse_app/features/patient/application/patient_notifier.dart';
import 'package:nurse_pulse_app/features/vital_sign/application/vital_sign_effects.dart';
import 'package:nurse_pulse_app/features/vital_sign/application/vital_sign_notifier.dart';
import 'package:nurse_pulse_app/features/vital_sign/domain/vital_sign.dart';

import 'fixtures.dart';

void main() {
  test('detalle consulta ID e historial con los endpoints existentes y ordena signos', () async {
    final paths = <String>[];

    Map<String, dynamic> vital(String id, String timestamp) => {
      'id': id,
      'patientId': 7,
      'nurseId': 2,
      'heartRate': 80,
      'respiratoryRate': 16,
      'systolic': 120,
      'diastolic': 80,
      'oxygenSaturation': 98,
      'temperature': 36.5,
      'riskLevel': 'LOW',
      'recordedAt': timestamp,
    };

    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          paths.add(options.path);

          final data = switch (options.path) {
            '/patients/7' => {'id': 7, ...patientCommand().toJson()},
            '/vital-sign-records/patients/7' => [
              vital('1', '2025-01-01T10:00:00Z'),
              vital('2', '2025-02-01T10:00:00Z'),
            ],
            '/clinical-events/patients/7' || '/alerts/patients/7' => <Object>[],
            _ => throw StateError('Endpoint inesperado: ${options.path}'),
          };

          handler.resolve(
            Response(requestOptions: options, data: data, statusCode: 200),
          );
        },
      ),
    );

    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        patientMonitoringRolesProvider.overrideWithValue([kRoleNurse]),
      ],
    );

    final patientSub = container.listen(patientDetailProvider('7'), (_, _) {});
    final historySub = container.listen(patientHistoryProvider('7'), (_, _) {});

    addTearDown(() {
      patientSub.close();
      historySub.close();
      container.dispose();
      dio.close();
    });

    final patient = await container.read(patientDetailProvider('7').future);
    final history = await container.read(patientHistoryProvider('7').future);

    expect(patient.id, '7');
    expect(history.vitals.map((v) => v.id), ['2', '1']);
    expect(
      paths,
      containsAll([
        '/patients/7',
        '/vital-sign-records/patients/7',
        '/clinical-events/patients/7',
        '/alerts/patients/7',
      ]),
    );
    expect(paths, isNot(contains('/patients')));
  });

  test('catálogo usa /users, filtra doctores y conserva el nombre visible de la web', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.path, '/users');

          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: [
                {
                  'id': 1,
                  'username': 'nurse',
                  'roles': ['ROLE_NURSE'],
                },
                {
                  'id': 2,
                  'username': 'doctor',
                  'firstName': 'Luis',
                  'lastName': 'Soto',
                  'roles': ['ROLE_DOCTOR'],
                },
                {
                  'id': 3,
                  'username': 'doctor.ana',
                  'roles': ['ROLE_DOCTOR'],
                },
              ],
            ),
          );
        },
      ),
    );

    final container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );

    final sub = container.listen(patientDoctorsProvider, (_, _) {});

    addTearDown(() {
      sub.close();
      container.dispose();
      dio.close();
    });

    expect(await container.read(patientDoctorsProvider.future), [
      'Luis Soto',
      'doctor.ana',
    ]);
  });

  test('guardar signos actualiza el historial del paciente', () async {
    var reads = 0;
    final records = <Map<String, dynamic>>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          Object data;

          if (options.path == '/patients/1') {
            data = {'id': 1, ...patientCommand().toJson()};
          } else if (options.path == '/vital-sign-records/patients/1') {
            reads++;
            data = List<Map<String, dynamic>>.of(records);
          } else if (options.path == '/clinical-events/patients/1' ||
              options.path == '/alerts/patients/1') {
            data = <Object>[];
          } else if (options.path == '/vital-sign-records' &&
              options.method == 'POST') {
            final sent = options.data as Map<String, dynamic>;

            final saved = <String, dynamic>{
              'id': 1,
              'patientId': sent['patientId'],
              'nurseId': sent['nurseId'],
              'heartRate': sent['heartRate'],
              'respiratoryRate': sent['respiratoryRate'],
              'systolic': sent['systolicPressure'],
              'diastolic': sent['diastolicPressure'],
              'oxygenSaturation': sent['oxygenSaturation'],
              'temperature': sent['temperature'],
              'riskLevel': 'LOW',
              'recordedAt': '2026-10-04T12:00:00Z',
            };

            records.add(saved);
            data = saved;
          } else {
            throw StateError('Endpoint inesperado: ${options.path}');
          }

          handler.resolve(
            Response(requestOptions: options, data: data, statusCode: 200),
          );
        },
      ),
    );

    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        vitalSignUserProvider.overrideWithValue(
          const User(id: '2', username: 'nurse.test', roles: [kRoleNurse]),
        ),
        vitalSignEffectsProvider.overrideWithValue(
          // Los efectos y el historial usan sesiones clínicas simuladas.
          VitalSignEffects(
            audit: (_, _) async {},
            createAlert: (_, _) async {},
          ),
        ),
        patientMonitoringRolesProvider.overrideWithValue([kRoleNurse]),
      ],
    );

    final sub = container.listen(patientHistoryProvider('1'), (_, _) {});

    addTearDown(() {
      sub.close();
      container.dispose();
      dio.close();
    });

    expect(
      (await container.read(patientHistoryProvider('1').future)).vitals,
      isEmpty,
    );

    await container
        .read(vitalSignNotifierProvider.notifier)
        .record(
          const RecordVitalSignCommand(
            patientId: '1',
            nurseId: '999',
            heartRate: 78,
            respiratoryRate: 18,
            systolicPressure: 120,
            diastolicPressure: 80,
            oxygenSaturation: 98,
            temperature: 36.5,
          ),
        );

    final history = await container.read(patientHistoryProvider('1').future);

    expect(reads, 2);
    expect(history.vitals.single.nurseId, '2');
  });
}
