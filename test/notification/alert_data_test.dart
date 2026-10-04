import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/core/network/dio_client.dart';
import 'package:nurse_pulse_app/features/clinical_event/application/clinical_event_notifier.dart';
import 'package:nurse_pulse_app/features/clinical_event/domain/clinical_event.dart';
import 'package:nurse_pulse_app/features/notification/application/alert_notifier.dart';
import 'package:nurse_pulse_app/features/notification/domain/alert.dart';
import 'package:nurse_pulse_app/features/notification/domain/alert_rules.dart';
import 'package:nurse_pulse_app/features/notification/infrastructure/alert_api.dart';
import 'package:nurse_pulse_app/features/patient/application/patient_detail.dart';
import 'package:nurse_pulse_app/features/vital_sign/application/vital_sign_notifier.dart';
import 'package:nurse_pulse_app/features/vital_sign/domain/vital_sign.dart';

import '../patient/fixtures.dart';
import 'fixtures.dart';

Dio mockDio(Object? Function(RequestOptions) response, {List<String>? paths}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        paths?.add('${options.method} ${options.path}');
        try {
          handler.resolve(
            Response(
              requestOptions: options,
              // Igual que una respuesta JSON real de Dio: objetos con claves String.
              data: jsonDecode(jsonEncode(response(options))),
              statusCode: options.method == 'POST' ? 201 : 200,
            ),
          );
        } on DioException catch (e) {
          handler.reject(e);
        }
      },
    ),
  );
  addTearDown(dio.close);
  return dio;
}

void main() {
  for (final severity in AlertSeverity.values) {
    test(
      'contrato POST $severity: campos y respuesta sin datos inventados',
      () async {
        final paths = <String>[];
        final dio = mockDio((options) {
          expect(options.path, '/alerts');
          expect(options.method, 'POST');
          final data = options.data as Map;
          expect(data, {
            'patientId': 1,
            'type': 'OTHER',
            'severity': severity.wireValue,
            'description': 'x' * 255,
            'triggeredBy': alertDefaultActor,
          });
          return {
            ...alertJson(severity: severity.wireValue),
            'description': data['description'],
          };
        }, paths: paths);
        final result = await AlertApi(dio).create(
          patientId: '1',
          type: 'OTHER',
          severity: severity,
          description: 'x' * 255,
          triggeredBy: alertDefaultActor,
        );
        expect(result.alert!.severity, severity);
        expect(result.readError, isNull);
        expect(result.alert!.triggeredAt, DateTime(2026, 10, 4, 12));
        expect(paths, ['POST /alerts']);
      },
    );
  }
  test('lecturas existentes global, paciente y por ID', () async {
    final paths = <String>[];
    final dio = mockDio(
      (options) => options.path == '/alerts/9' ? alertJson() : [alertJson()],
      paths: paths,
    );
    final api = AlertApi(dio);
    expect((await api.getAll()).single.id, '9');
    expect((await api.getByPatientId('1')).single.patientId, '1');
    expect((await api.getById('9')).id, '9');
    expect(paths, ['GET /alerts', 'GET /alerts/patients/1', 'GET /alerts/9']);
  });
  test('detalle con otro ID rechazado', () async {
    final dio = mockDio((_) => alertJson(id: '10'));
    await expectLater(AlertApi(dio).getById('9'), throwsFormatException);
  });
  for (final closing in [false, true]) {
    test(
      'PATCH cierre=$closing usa actor y estado que devuelve servidor',
      () async {
        final paths = <String>[];
        final dio = mockDio((options) {
          expect(
            options.path,
            closing ? '/alerts/9/close' : '/alerts/9/attend',
          );
          expect(options.method, 'PATCH');
          expect(
            options.data,
            closing
                ? {
                    'closedBy': doctor.username,
                    'resolutionNotes': alertClosingNotes,
                  }
                : {'attendedBy': nurse.username},
          );
          return alertJson(
            status: closing ? 'CLOSED' : 'ATTENDED',
            attendedBy: 'actor.devuelto',
            closedBy: closing ? 'medico.devuelto' : null,
          );
        }, paths: paths);
        final api = AlertApi(dio);
        final result = closing
            ? await api.close('9', doctor.username)
            : await api.attend('9', nurse.username);
        expect(result.alert!.attendedBy, 'actor.devuelto');
        expect(result.alert!.closedBy, closing ? 'medico.devuelto' : null);
        expect(result.readError, isNull);
        expect(paths, hasLength(1));
      },
    );
  }
  for (final operation in ['POST', 'attend', 'close']) {
    for (final recover in [false, true]) {
      test(
        '$operation 2xx malformado: GET recupera=$recover, nunca repite escritura',
        () async {
          final paths = <String>[];
          final status = operation == 'POST'
              ? 'OPEN'
              : operation == 'attend'
              ? 'ATTENDED'
              : 'CLOSED';
          final dio = mockDio((options) {
            if (options.method == 'GET') {
              if (!recover) throw httpFailure(503);
              return alertJson(status: status);
            }
            return {'id': 9};
          }, paths: paths);
          final api = AlertApi(dio);
          final receipt = operation == 'POST'
              ? await api.create(
                  patientId: '1',
                  type: 'CARDIAC',
                  severity: AlertSeverity.critical,
                  description: 'Alerta ficticia',
                  triggeredBy: alertDefaultActor,
                )
              : operation == 'attend'
              ? await api.attend('9', nurse.username)
              : await api.close('9', doctor.username);
          expect(receipt.id, '9');
          expect(receipt.alert == null, !recover);
          expect(receipt.readError == null, recover);
          expect(paths.where((p) => !p.startsWith('GET')), hasLength(1));
          expect(paths.last, 'GET /alerts/9');
        },
      );
    }
  }
  test('POST 2xx sin ID no simula entidad ni éxito del detalle', () async {
    final paths = <String>[];
    final dio = mockDio((_) => 'cuerpo inválido', paths: paths);
    final receipt = await AlertApi(dio).create(
      patientId: '1',
      type: 'CARDIAC',
      severity: AlertSeverity.critical,
      description: 'x',
      triggeredBy: alertDefaultActor,
    );
    expect(receipt.id, isNull);
    expect(receipt.alert, isNull);
    expect(receipt.readError, isNotNull);
    expect(paths, ['POST /alerts']);
  });
  test('PATCH con otro ID recupera solo el ID solicitado', () async {
    final paths = <String>[];
    final dio = mockDio(
      (o) => o.method == 'GET'
          ? alertJson(status: 'ATTENDED')
          : alertJson(id: '10', status: 'ATTENDED'),
      paths: paths,
    );
    final receipt = await AlertApi(dio).attend('9', nurse.username);
    expect(receipt.alert!.id, '9');
    expect(paths, ['PATCH /alerts/9/attend', 'GET /alerts/9']);
  });
  test('estado contrario tras PATCH confirmado no se fabrica', () async {
    final paths = <String>[];
    final dio = mockDio((_) => alertJson(status: 'OPEN'), paths: paths);
    final receipt = await AlertApi(dio).close('9', doctor.username);
    expect(receipt.alert, isNull);
    expect(receipt.readError, isNotNull);
    expect(paths, ['PATCH /alerts/9/close', 'GET /alerts/9']);
  });
  test(
    'escrituras reales simuladas invalidan detalle e historial observado',
    () async {
      final paths = <String>[];
      Map<String, dynamic>? saved;
      final dio = mockDio((o) {
        if (o.path == '/patients/1') {
          return {'id': 1, ...patientCommand().toJson()};
        }
        if (o.path == '/vital-sign-records/patients/1' ||
            o.path == '/clinical-events/patients/1') {
          return <Object>[];
        }
        if (o.path == '/alerts/patients/1') {
          return [if (saved != null) Map<String, dynamic>.of(saved!)];
        }
        if (o.path == '/alerts' && o.method == 'POST') {
          saved = alertJson();
          return Map<String, dynamic>.of(saved!);
        }
        if (o.path == '/alerts/9') return Map<String, dynamic>.of(saved!);
        if (o.path == '/alerts/9/attend') {
          saved = alertJson(status: 'ATTENDED', attendedBy: doctor.username);
          return Map<String, dynamic>.of(saved!);
        }
        if (o.path == '/alerts/9/close') {
          saved = alertJson(
            status: 'CLOSED',
            attendedBy: doctor.username,
            closedBy: doctor.username,
          );
          return Map<String, dynamic>.of(saved!);
        }
        if (o.path == '/audit-logs') {
          expect((o.data as Map)['performedBy'], doctor.username);
          expect([
            'ALERT_TRIGGERED',
            'ALERT_ACKNOWLEDGED',
            'UPDATE',
          ], contains((o.data as Map)['actionType']));
          return {
            'id': 5,
            ...o.data as Map,
            'performedAt': '2026-10-04T12:00:00',
          };
        }
        throw StateError('Endpoint inesperado ${o.path}');
      }, paths: paths);
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(dio),
          alertUserProvider.overrideWithValue(doctor),
        ],
      );
      final history = container.listen(patientHistoryProvider('1'), (_, _) {});
      addTearDown(() {
        history.close();
        container.dispose();
      });
      expect(
        (await container.read(patientHistoryProvider('1').future)).alerts,
        isEmpty,
      );
      final notifier = container.read(alertNotifierProvider.notifier);
      await notifier.create(
        patientId: '1',
        type: 'CARDIAC',
        severity: AlertSeverity.critical,
        description: 'x',
      );
      final detail = container.listen(alertDetailProvider('9'), (_, _) {});
      addTearDown(detail.close);
      expect(
        (await container.read(alertDetailProvider('9').future)).status,
        AlertStatus.open,
      );
      expect(
        (await container.read(patientHistoryProvider('1').future))
            .alerts
            .single
            .status,
        AlertStatus.open,
      );
      await notifier.attend('9');
      expect(
        (await container.read(alertDetailProvider('9').future)).status,
        AlertStatus.attended,
      );
      expect(
        (await container.read(patientHistoryProvider('1').future))
            .alerts
            .single
            .status,
        AlertStatus.attended,
      );
      await notifier.close('9');
      expect(
        (await container.read(alertDetailProvider('9').future)).status,
        AlertStatus.closed,
      );
      expect(
        (await container.read(patientHistoryProvider('1').future))
            .alerts
            .single
            .status,
        AlertStatus.closed,
      );
      expect(paths.where((p) => p == 'POST /alerts'), hasLength(1));
      expect(paths.where((p) => p == 'PATCH /alerts/9/attend'), hasLength(1));
      expect(paths.where((p) => p == 'PATCH /alerts/9/close'), hasLength(1));
      expect(paths.where((p) => p == 'POST /audit-logs'), hasLength(3));
      expect(container.read(alertNotifierProvider).warning, isNull);
    },
  );
  test('detalle inválido o sin permiso no llama API', () async {
    final api = FakeAlertApi();
    final container = ProviderContainer(
      overrides: [
        alertApiProvider.overrideWithValue(api),
        alertUserProvider.overrideWithValue(nurse),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(alertDetailProvider('abc').future),
      throwsFormatException,
    );
    container.updateOverrides([
      alertApiProvider.overrideWithValue(api),
      alertUserProvider.overrideWithValue(null),
    ]);
    await expectLater(
      container.read(alertDetailProvider('9').future),
      throwsFormatException,
    );
    expect(api.detailReads, 0);
  });

  test(
    'PATCH con otro paciente confirmado no fabrica detalle del solicitado',
    () async {
      final paths = <String>[];
      final dio = mockDio(
        (_) => alertJson(patientId: '2', status: 'ATTENDED'),
        paths: paths,
      );
      final receipt = await AlertApi(dio)
          .attend('9', nurse.username, patientId: '1');
      expect(receipt.id, '9');
      expect(receipt.alert, isNull);
      expect(receipt.readError, isNotNull);
      expect(paths, ['PATCH /alerts/9/attend', 'GET /alerts/9']);
    },
  );

  for (final source in ['event', 'vital']) {
    for (final response in ['valid', 'malformed', 'auditFailure']) {
      test(
        'alerta automática $source/$response no repite registro clínico',
        () async {
          final paths = <String>[];
          final dio = mockDio((o) {
            if (o.path == '/patients/1') {
              return {'id': 1, ...patientCommand().toJson()};
            }
            if (o.path == '/audit-logs') {
              expect([
                'CREATE',
                'VITAL_SIGNS_RECORDED',
                'ALERT_TRIGGERED',
              ], contains((o.data as Map)['actionType']));
              if (response == 'auditFailure' &&
                  (o.data as Map)['entityType'] == 'ALERT') {
                throw httpFailure(503);
              }
              return {
                'id': 5,
                ...o.data as Map,
                'performedAt': '2026-10-04T12:00:00',
              };
            }
            if (o.path == '/alerts' && o.method == 'POST') {
              final data = o.data as Map;
              expect(data['type'], source == 'event' ? 'OTHER' : 'RESPIRATORY');
              expect(data['severity'], 'CRITICAL');
              expect(
                (data['description'] as String).length,
                lessThanOrEqualTo(255),
              );
              return response == 'malformed'
                  ? {'id': 9}
                  : {...alertJson(), ...data};
            }
            if (o.path == '/alerts/9') throw httpFailure(503);
            throw StateError('Endpoint inesperado ${o.path}');
          }, paths: paths);
          final container = ProviderContainer(
            overrides: [
              dioProvider.overrideWithValue(dio),
              alertUserProvider.overrideWithValue(nurse),
            ],
          );
          addTearDown(container.dispose);
          final warning = source == 'event'
              ? await container
                    .read(clinicalEventEffectsProvider)
                    .run(
                      ClinicalEvent(
                        id: '7',
                        patientId: '1',
                        eventType: 'OBSERVATION',
                        severity: 'CRITICAL',
                        title: 'Evento ficticio',
                        description: 'Descripción ficticia de prueba',
                        registeredBy: nurse.username,
                        occurredAt: DateTime(2026, 10, 4),
                      ),
                      nurse,
                    )
              : await container
                    .read(vitalSignEffectsProvider)
                    .run(
                      VitalSign(
                        id: '8',
                        patientId: '1',
                        nurseId: nurse.id,
                        heartRate: 140,
                        respiratoryRate: 30,
                        systolic: 190,
                        diastolic: 110,
                        oxygenSaturation: 80,
                        temperature: 40,
                        riskLevel: RiskLevel.critical,
                        recordedAt: DateTime(2026, 10, 4),
                      ),
                      nurse,
                    );
          expect(
            warning == null,
            response == 'valid',
            reason: '$warning; $paths',
          );
          if (response != 'valid') {
            expect(warning, contains('Revisa Alertas'));
            expect(container.read(alertNotifierProvider).warning, isNotNull);
          }
          expect(paths.where((p) => p == 'POST /alerts'), hasLength(1));
          expect(
            paths.any(
              (p) =>
                  p.contains('/clinical-events') ||
                  p.contains('/vital-sign-records'),
            ),
            isFalse,
          );
          expect(container.read(alertNotifierProvider).saving, isFalse);
        },
      );
    }
  }
}
