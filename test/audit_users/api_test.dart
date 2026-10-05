import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/audit/infrastructure/audit_api.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/iam/infrastructure/iam_api.dart';

import 'fixtures.dart';

Map<String, dynamic> pageJson({int page = 0}) => {
  'content': [logJson()],
  'page': page,
  'size': 100,
  'totalElements': 250,
  'totalPages': 3,
  'last': page == 2,
};

void main() {
  test('página respeta parámetros y metadatos del contrato', () async {
    final api = AuditApi(
      mockDio((request) {
        expect(request.path, '/audit-logs');
        expect(request.queryParameters, {'page': 1, 'size': 100});
        return pageJson(page: 1);
      }),
    );
    final page = await api.getPage(page: 1);
    expect(page.page, 1);
    expect(page.totalElements, 250);
    expect(page.last, isFalse);
  });
  test('lista heredada se conserva sin fabricar total global', () async {
    final api = AuditApi(mockDio((_) => [logJson()]));
    final page = await api.getPage();
    expect(page.logs, hasLength(1));
    expect(page.totalElements, isNull);
    expect(page.last, isTrue);
    await expectLater(api.getPage(page: 1), throwsFormatException);
  });
  for (final record in [(-1, 100), (0, 201), (0, 0)]) {
    test('paginación inválida $record no llama API', () async {
      final paths = <String>[];
      final api = AuditApi(mockDio((_) => pageJson(), paths: paths));
      await expectLater(
        api.getPage(page: record.$1, size: record.$2),
        throwsFormatException,
      );
      expect(paths, isEmpty);
    });
  }
  for (final field in {
    'page': 1,
    'size': 201,
    'totalElements': -1,
    'totalPages': -1,
    'last': 'false',
    'content': null,
  }.entries) {
    test('metadato inválido ${field.key} es error', () async {
      final api = AuditApi(
        mockDio((_) => {...pageJson(), field.key: field.value}),
      );
      await expectLater(api.getPage(), throwsFormatException);
    });
  }
  test('duplicados en página se rechazan', () async {
    final api = AuditApi(
      mockDio(
        (_) => {
          ...pageJson(),
          'content': [logJson(), logJson()],
        },
      ),
    );
    await expectLater(api.getPage(), throwsFormatException);
  });
  for (final legacy in [false, true]) {
    test(
      'timeline ${legacy ? 'heredado' : 'envelope real'} por paciente',
      () async {
        final api = AuditApi(
          mockDio((request) {
            expect(request.path, '/audit-logs/patients/1/timeline');
            return legacy
                ? [logJson(patientId: '1')]
                : {
                    'patientId': 1,
                    'eventCount': 1,
                    'events': [logJson()..remove('patientId')],
                  };
          }),
        );
        expect((await api.getPatientTimeline(' 001 ')).single.patientId, '1');
      },
    );
  }
  for (final response in [
    {
      'patientId': 2,
      'eventCount': 1,
      'events': [logJson()],
    },
    {
      'patientId': 1,
      'eventCount': 9,
      'events': [logJson()],
    },
    {
      'patientId': 1,
      'eventCount': 1,
      'events': [logJson(patientId: '2')],
    },
  ]) {
    test(
      'timeline inválido rechaza mezcla de paciente o contador $response',
      () async {
        await expectLater(
          AuditApi(mockDio((_) => response)).getPatientTimeline('1'),
          throwsFormatException,
        );
      },
    );
  }
  test('IDs inválidos de timeline y PDF no llaman API', () async {
    final paths = <String>[];
    final api = AuditApi(mockDio((_) => [], paths: paths));
    await expectLater(api.getPatientTimeline('0'), throwsFormatException);
    await expectLater(api.exportPdf(patientId: '-1'), throwsFormatException);
    expect(paths, isEmpty);
  });
  for (final id in [null, '1']) {
    test('PDF $id usa bytes y endpoint existente, sin POST cliente', () async {
      final paths = <String>[];
      final api = AuditApi(
        mockDio((request) {
          expect(request.path, '/audit-logs/export/pdf');
          expect(request.responseType, ResponseType.bytes);
          expect(request.headers['Accept'], 'application/pdf');
          expect(request.queryParameters, {if (id != null) 'patientId': 1});
          return pdf;
        }, paths: paths),
      );
      expect(await api.exportPdf(patientId: id), pdf);
      expect(paths, ['GET /audit-logs/export/pdf']);
    });
  }
  for (final body in [
    Uint8List(0),
    Uint8List.fromList('error'.codeUnits),
    Uint8List.fromList('%PDF-1.4 incomplete'.codeUnits),
  ]) {
    test('PDF inválido o incompleto no se declara exportado $body', () async {
      await expectLater(
        AuditApi(mockDio((_) => body)).exportPdf(),
        throwsFormatException,
      );
    });
  }
  for (final response in [
    null,
    {'id': 2},
    {
      ...userJson(),
      'roles': ['UNKNOWN'],
    },
    {...userJson(), 'id': 9},
  ]) {
    test('PATCH 2xx ilegible se recupera solo por GET: $response', () async {
      final paths = <String>[];
      final api = UsersApi(
        mockDio((request) {
          expect(
            request.path,
            request.method == 'PATCH' ? '/users/2/roles' : '/users/2',
          );
          if (request.method == 'PATCH') {
            expect(request.data, {
              'roles': [kRoleDoctor],
            });
            return response;
          }
          return userJson(role: kRoleDoctor);
        }, paths: paths),
      );
      final receipt = await api.updateRoles('002', [kRoleDoctor]);
      expect(receipt.user!.primaryRole, kRoleDoctor);
      expect(receipt.readError, isNull);
      expect(paths, ['PATCH /users/2/roles', 'GET /users/2']);
    });
  }
  test('PATCH confirmado y recuperación fallida conserva confirmación sin detalle ficticio', () async {
    final paths = <String>[];
    final api = UsersApi(
      mockDio((request) {
        if (request.method == 'GET') throw httpFailure(503);
        return {'id': 2};
      }, paths: paths),
    );
    final receipt = await api.updateRoles('2', [kRoleDoctor]);
    expect(receipt.id, '2');
    expect(receipt.user, isNull);
    expect(receipt.readError, isNotNull);
    expect(paths, ['PATCH /users/2/roles', 'GET /users/2']);
  });
  test('PATCH válido no realiza GET adicional', () async {
    final paths = <String>[];
    final api = UsersApi(
      mockDio((_) => userJson(role: kRoleDoctor), paths: paths),
    );
    expect(
      (await api.updateRoles('2', [kRoleDoctor])).user!.primaryRole,
      kRoleDoctor,
    );
    expect(paths, ['PATCH /users/2/roles']);
  });
  for (final code in [400, 401, 403, 404, 422, 503]) {
    test(
      'PATCH HTTP $code no hace recuperación ni declara confirmado',
      () async {
        final paths = <String>[];
        final api = UsersApi(
          mockDio((_) => throw httpFailure(code), paths: paths),
        );
        await expectLater(
          api.updateRoles('2', [kRoleDoctor]),
          throwsA(isA<DioException>()),
        );
        expect(paths, ['PATCH /users/2/roles']);
      },
    );
  }
  test('API de roles rechaza entradas inválidas antes de llamar', () async {
    final paths = <String>[];
    final api = UsersApi(mockDio((_) => userJson(), paths: paths));
    await expectLater(
      api.updateRoles('0', [kRoleDoctor]),
      throwsFormatException,
    );
    await expectLater(api.updateRoles('2', []), throwsFormatException);
    await expectLater(api.updateRoles('2', ['UNKNOWN']), throwsFormatException);
    await expectLater(api.getById('1.5'), throwsFormatException);
    expect(paths, isEmpty);
  });
}
