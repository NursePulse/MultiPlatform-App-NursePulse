import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/core/network/dio_client.dart';
import 'package:nurse_pulse_app/features/sbar/application/sbar_notifier.dart';
import 'package:nurse_pulse_app/features/sbar/infrastructure/sbar_api.dart';

import '../patient/fixtures.dart';
import 'fixtures.dart';

void main() {
  for (final responseId in [9, '9']) {
    test(
      'POST devuelve ID $responseId; GET obtiene detalle sin repetir escritura',
      () async {
        final methods = <String>[];
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              methods.add('${options.method} ${options.path}');
              if (options.method == 'POST') {
                expect(options.path, '/handovers');
                expect((options.data as Map<String, dynamic>).keys.toSet(), {
                  'patientId',
                  'targetNurseId',
                  'title',
                  'situation',
                  'background',
                  'assessment',
                  'recommendation',
                });
                handler.resolve(
                  Response(
                    requestOptions: options,
                    data: responseId,
                    statusCode: 201,
                  ),
                );
              } else {
                expect(options.path, '/handovers/9');
                handler.resolve(
                  Response(
                    requestOptions: options,
                    data: transferJson(),
                    statusCode: 200,
                  ),
                );
              }
            },
          ),
        );
        addTearDown(dio.close);
        final result = await SbarApi(dio).register(command());
        expect(result.id, '9');
        expect(result.transfer!.registeredBy, actor.username);
        expect(methods, ['POST /handovers', 'GET /handovers/9']);
      },
    );
  }
  test(
    'GET fallido tras POST confirmado conserva ID sin inventar SbarTransfer',
    () async {
      var posts = 0, gets = 0;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'POST') {
              posts++;
              handler.resolve(
                Response(requestOptions: options, data: 9, statusCode: 201),
              );
            } else {
              gets++;
              handler.reject(httpFailure(503));
            }
          },
        ),
      );
      addTearDown(dio.close);
      final result = await SbarApi(dio).register(command());
      expect(result.id, '9');
      expect(result.transfer, isNull);
      expect(result.readError, isA<DioException>());
      expect(posts, 1);
      expect(gets, 1);
    },
  );
  test(
    'respuesta confirmada ilegible no convierte el POST en fallo reintentable',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response(
              requestOptions: options,
              data: {'unexpected': true},
              statusCode: 201,
            ),
          ),
        ),
      );
      addTearDown(dio.close);
      final result = await SbarApi(dio).register(command());
      expect(result.id, isNull);
      expect(result.transfer, isNull);
      expect(result.readError, isNotNull);
    },
  );
  test(
    'mapa compatible devuelve recurso del servidor sin GET adicional',
    () async {
      var calls = 0;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls++;
            handler.resolve(
              Response(
                requestOptions: options,
                data: transferJson(),
                statusCode: 201,
              ),
            );
          },
        ),
      );
      addTearDown(dio.close);
      expect((await SbarApi(dio).register(command())).transfer!.id, '9');
      expect(calls, 1);
    },
  );
  test(
    'PATCH envía solo notas; respuesta del servidor identifica a receptor real',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, '/handovers/9/acknowledge');
            expect(options.method, 'PATCH');
            expect(options.data, {'additionalNotes': sbarAcknowledgementNotes});
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: transferJson(
                  status: 'ACKNOWLEDGED',
                  incoming: '2',
                  notes: sbarAcknowledgementNotes,
                ),
              ),
            );
          },
        ),
      );
      addTearDown(dio.close);
      final result = await SbarApi(dio)
          .acknowledge('9', additionalNotes: sbarAcknowledgementNotes);
      expect(result.transfer!.incomingNurseId, '2');
      expect(result.transfer!.status, 'ACKNOWLEDGED');
    },
  );
  test('PATCH confirmado con respuesta rota conserva confirmación sin fabricar estado', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response(requestOptions: options, statusCode: 200, data: {}),
        ),
      ),
    );
    addTearDown(dio.close);
    final result = await SbarApi(dio).acknowledge('9');
    expect(result.id, '9');
    expect(result.transfer, isNull);
    expect(result.readError, isNotNull);
  });
  test(
    'POST/PATCH rechazado no devuelve confirmación ni hace GET posterior',
    () async {
      var gets = 0;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'GET') gets++;
            handler.reject(httpFailure(409));
          },
        ),
      );
      addTearDown(dio.close);
      await expectLater(
        SbarApi(dio).register(command()),
        throwsA(isA<DioException>()),
      );
      await expectLater(
        SbarApi(dio).acknowledge('9'),
        throwsA(isA<DioException>()),
      );
      expect(gets, 0);
    },
  );
  test('paridad completa simulada: campos máximos, catálogo, listado, recepción y detalle actualizado', () async {
    final paths = <String>[];
    Map<String, dynamic>? saved;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          paths.add('${options.method} ${options.path}');
          Object data;
          if (options.path == '/patients/1') {
            data = {'id': 1, ...patientCommand().toJson()};
          } else if (options.path == '/patients') {
            data = [
              {'id': 1, ...patientCommand().toJson()},
            ];
          } else if (options.path == '/users') {
            data = [actor.toJson(), receiver.toJson()];
          } else if (options.path == '/handovers' && options.method == 'POST') {
            final sent = options.data as Map<String, dynamic>;
            expect(sent['patientId'], 1);
            expect(sent['targetNurseId'], 3);
            for (final field in [
              'situation',
              'background',
              'assessment',
              'recommendation',
            ]) {
              expect((sent[field] as String).length, 1000);
            }
            saved = {...transferJson(), ...sent};
            data = 9;
          } else if (options.path == '/handovers/9') {
            data = Map<String, dynamic>.of(saved!);
          } else if (options.path == '/handovers/9/acknowledge') {
            expect(options.data, {'additionalNotes': sbarAcknowledgementNotes});
            saved = {
              ...saved!,
              'status': 'ACKNOWLEDGED',
              'incomingNurseId': 2,
              'additionalNotes': sbarAcknowledgementNotes,
            };
            data = saved!;
          } else if (options.path == '/handovers/patients/1') {
            data = saved == null
                ? <Object>[]
                : [Map<String, dynamic>.of(saved!)];
          } else if (options.path == '/audit-logs') {
            final sent = options.data as Map<String, dynamic>;
            expect(sent['performedBy'], actor.username);
            expect(sent['entityType'], 'SBAR_HANDOVER');
            expect(sent['actionType'], 'HANDOVER');
            data = {'id': 5, ...sent, 'performedAt': '2026-10-04T12:00:00Z'};
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
        sbarUserProvider.overrideWithValue(actor),
      ],
    );
    addTearDown(() {
      container.dispose();
      dio.close();
    });
    final notifier = container.read(sbarNotifierProvider.notifier);
    await notifier.load();
    expect(container.read(sbarNotifierProvider).transfers, isEmpty);
    await notifier.register(
      command(
        situation: ' ${'S' * 1000} ',
        background: ' ${'B' * 1000} ',
        assessment: ' ${'A' * 1000} ',
        recommendation: ' ${'R' * 1000} ',
      ),
    );
    expect(container.read(sbarNotifierProvider).transfers.single.id, '9');
    final sub = container.listen(sbarDetailProvider('9'), (_, _) {});
    addTearDown(sub.close);
    expect(
      (await container.read(sbarDetailProvider('9').future)).status,
      'PENDING',
    );
    await notifier.acknowledge('9');
    expect(
      (await container.read(sbarDetailProvider('9').future)).status,
      'ACKNOWLEDGED',
    );
    expect(
      container.read(sbarNotifierProvider).transfers.single.incomingNurseId,
      '2',
    );
    await notifier.load();
    expect(
      container.read(sbarNotifierProvider).transfers.single.status,
      'ACKNOWLEDGED',
    );
    expect(paths.where((p) => p == 'POST /handovers'), hasLength(1));
    expect(
      paths.where((p) => p == 'PATCH /handovers/9/acknowledge'),
      hasLength(1),
    );
    expect(paths, isNot(contains('GET /handovers')));
    expect(paths, isNot(contains('GET /roles')));
    expect(paths, isNot(contains('GET /users/3')));
    expect(container.read(sbarNotifierProvider).warning, isNull);
  });
}
