import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/core/network/dio_client.dart';
import 'package:nurse_pulse_app/core/storage/secure_store.dart';
import 'package:nurse_pulse_app/features/clinical_event/application/clinical_event_notifier.dart';
import 'package:nurse_pulse_app/features/notification/application/alert_notifier.dart';
import 'package:nurse_pulse_app/features/patient/application/patient_detail.dart';

import '../patient/fixtures.dart';
import 'fixtures.dart';

class EmptyMemoryStore extends SecureStore {
  @override
  Future<String?> readToken() async => null;
  @override
  Future<Map<String, dynamic>?> readUser() async => null;
}

void main() {
  for (final severity in ['HIGH', 'CRITICAL']) {
    test(
      'contrato real simulado $severity: POST, alerta, auditoría e historial',
      () async {
        final paths = <String>[];
        final events = <Map<String, dynamic>>[];
        final alerts = <Map<String, dynamic>>[];
        var historyReads = 0;
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              paths.add('${options.method} ${options.path}');
              Object data;
              if (options.path == '/patients/1') {
                data = {'id': 1, ...patientCommand().toJson()};
              } else if (options.path == '/clinical-events' &&
                  options.method == 'POST') {
                final sent = options.data as Map<String, dynamic>;
                expect(sent.keys.toSet(), {
                  'patientId',
                  'eventType',
                  'severity',
                  'title',
                  'description',
                });
                expect(sent['patientId'], 1);
                expect(sent['eventType'], 'OBSERVATION');
                expect(sent['severity'], severity);
                expect(sent['title'], 'T' * 120);
                expect(sent['description'], 'D' * 1000);
                final created = <String, dynamic>{
                  'id': 9,
                  ...sent,
                  'registeredBy': actor.username,
                  'occurredAt': '2026-10-04T12:00:00',
                };
                events.add(created);
                data = created;
              } else if (options.path == '/alerts' &&
                  options.method == 'POST') {
                final sent = options.data as Map<String, dynamic>;
                expect(sent.keys.toSet(), {
                  'patientId',
                  'type',
                  'severity',
                  'description',
                  'triggeredBy',
                });
                expect(sent['type'], 'OTHER');
                expect(sent['severity'], severity);
                expect(
                  (sent['description'] as String).length,
                  lessThanOrEqualTo(255),
                );
                expect(sent['triggeredBy'], 'Equipo clínico');
                final created = <String, dynamic>{
                  'id': 11,
                  ...sent,
                  'status': 'OPEN',
                };
                alerts.add(created);
                data = created;
              } else if (options.path == '/audit-logs' &&
                  options.method == 'POST') {
                final sent = options.data as Map<String, dynamic>;
                if (sent['entityType'] == 'CLINICAL_EVENT') {
                  expect(sent['entityId'], '9');
                  expect(sent['actionType'], 'CREATE');
                  expect(sent['performedBy'], actor.username);
                }
                data = {'id': 3, ...sent, 'performedAt': '2026-10-04T12:00:00'};
              } else if (options.path == '/clinical-events/patients/1') {
                historyReads++;
                data = List<Map<String, dynamic>>.of(events);
              } else if (options.path == '/alerts/patients/1') {
                data = List<Map<String, dynamic>>.of(alerts);
              } else if (options.path == '/vital-sign-records/patients/1') {
                data = <Object>[];
              } else {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    error: StateError('Endpoint inesperado: ${options.path}'),
                  ),
                );
                return;
              }
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: data,
                  statusCode: options.method == 'POST' ? 201 : 200,
                ),
              );
            },
          ),
        );
        final container = ProviderContainer(
          overrides: [
            dioProvider.overrideWithValue(dio),
            clinicalEventUserProvider.overrideWithValue(actor),
            secureStoreProvider.overrideWithValue(EmptyMemoryStore()),
          ],
        );
        final history = container.listen(
          patientHistoryProvider('1'),
          (_, _) {},
        );
        addTearDown(() {
          history.close();
          container.dispose();
          dio.close();
        });
        expect(
          (await container.read(patientHistoryProvider('1').future)).events,
          isEmpty,
        );
        await container
            .read(clinicalEventNotifierProvider.notifier)
            .register(
              command(
                title: ' TTTT '.replaceAll('TTTT', 'T' * 120),
                description: ' ${'D' * 1000} ',
                severity: severity,
              ),
            );
        final updated = await container.read(
          patientHistoryProvider('1').future,
        );
        expect(historyReads, 2);
        expect(updated.events.single.id, '9');
        expect(updated.events.single.registeredBy, actor.username);
        expect(updated.alerts.single.id, '11');
        expect(container.read(alertNotifierProvider).alerts.single.id, '11');
        expect(paths.where((p) => p == 'POST /clinical-events'), hasLength(1));
        expect(paths.where((p) => p == 'POST /alerts'), hasLength(1));
        expect(container.read(clinicalEventNotifierProvider).warning, isNull);
      },
    );
  }
  for (final failingPath in ['/audit-logs', '/alerts']) {
    test(
      'fallo de $failingPath no repite evento confirmado ni declara éxito de efecto',
      () async {
        var posts = 0, alertPosts = 0;
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/clinical-events') posts++;
              if (options.path == '/alerts') alertPosts++;
              if (options.path == failingPath) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.badResponse,
                    response: Response(
                      requestOptions: options,
                      statusCode: 503,
                    ),
                  ),
                );
                return;
              }
              final sent = options.data as Map<String, dynamic>?;
              final data = switch (options.path) {
                '/patients/1' => {'id': 1, ...patientCommand().toJson()},
                '/clinical-events' => {
                  'id': 9,
                  ...sent!,
                  'registeredBy': actor.username,
                  'occurredAt': '2026-10-04T12:00:00',
                },
                '/alerts' => {'id': 11, ...sent!, 'status': 'OPEN'},
                '/audit-logs' => {
                  'id': 3,
                  ...sent!,
                  'performedAt': '2026-10-04T12:00:00',
                },
                _ => throw StateError('Endpoint inesperado: ${options.path}'),
              };
              handler.resolve(
                Response(requestOptions: options, data: data, statusCode: 201),
              );
            },
          ),
        );
        final container = ProviderContainer(
          overrides: [
            dioProvider.overrideWithValue(dio),
            clinicalEventUserProvider.overrideWithValue(actor),
            secureStoreProvider.overrideWithValue(EmptyMemoryStore()),
          ],
        );
        addTearDown(() {
          container.dispose();
          dio.close();
        });
        final saved = await container
            .read(clinicalEventNotifierProvider.notifier)
            .register(command(severity: 'HIGH'));
        expect(saved.id, '9');
        expect(
          container.read(clinicalEventNotifierProvider).events.single.id,
          '9',
        );
        expect(
          container.read(clinicalEventNotifierProvider).warning,
          contains(failingPath == '/alerts' ? 'Revisa Alertas' : 'auditoría'),
        );
        expect(posts, 1);
        expect(alertPosts, 1);
      },
    );
  }
}
