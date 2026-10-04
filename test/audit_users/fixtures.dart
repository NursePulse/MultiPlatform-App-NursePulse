import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/audit/domain/audit_log.dart';
import 'package:nurse_pulse_app/features/audit/domain/audit_page.dart';
import 'package:nurse_pulse_app/features/audit/infrastructure/audit_api.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/iam/infrastructure/iam_api.dart';

export '../dashboard/fixtures.dart' show nurse, doctor, admin, now;

Map<String, dynamic> userJson({
  String id = '2',
  String role = kRoleNurse,
  String username = 'nurse.test',
}) => {
  'id': int.parse(id),
  'username': username,
  'roles': [role],
  'firstName': 'Nombre ficticio',
  'lastName': 'Prueba',
};
User user({
  String id = '2',
  String role = kRoleNurse,
  String username = 'nurse.test',
}) => User.fromJson(userJson(id: id, role: role, username: username));

Map<String, dynamic> logJson({
  String id = '1',
  String? patientId,
  Object? metadata,
  String date = '2026-10-04T12:00:00Z',
}) => {
  'id': int.parse(id),
  'patientId': patientId == null ? null : int.parse(patientId),
  'entityType': 'PATIENT',
  'entityId': '1',
  'actionType': 'VIEW',
  'performedBy': 'doctor.test',
  'performedAt': date,
  'metadata': metadata,
};
AuditLog log({
  String id = '1',
  String? patientId,
  Object? metadata,
  String date = '2026-10-04T12:00:00Z',
}) => AuditLog.fromJson(
  logJson(id: id, patientId: patientId, metadata: metadata, date: date),
);

final pdf = Uint8List.fromList(
  ascii.encode('%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\n%%EOF\n'),
);

class FakeAuditApi extends AuditApi {
  FakeAuditApi() : super(Dio());
  AuditPage pageResult = const AuditPage(
    logs: [],
    page: 0,
    size: 100,
    totalElements: 0,
    totalPages: 0,
  );
  List<AuditLog> timeline = [];
  int pages = 0, timelines = 0, exports = 0;
  String? patientId;
  int? page;
  Object? failure, pdfFailure;
  Future<AuditPage> Function(int)? reading;
  Future<List<AuditLog>> Function(String)? readingTimeline;
  Future<Uint8List> Function()? exporting;
  @override
  Future<AuditPage> getPage({int page = 0, int size = 100}) async {
    pages++;
    this.page = page;
    if (failure != null) throw failure!;
    return reading == null ? pageResult : reading!(page);
  }

  @override
  Future<List<AuditLog>> getPatientTimeline(String id) async {
    timelines++;
    patientId = id;
    if (failure != null) throw failure!;
    return readingTimeline == null ? timeline : readingTimeline!(id);
  }

  @override
  Future<Uint8List> exportPdf({String? patientId}) async {
    exports++;
    this.patientId = patientId;
    if (pdfFailure != null) throw pdfFailure!;
    return exporting == null ? pdf : exporting!();
  }
}

class FakeUsersApi extends UsersApi {
  FakeUsersApi() : super(Dio());
  List<User> users = [
    user(),
    user(id: '4', role: kRoleAdmin, username: 'admin.test'),
  ];
  int lists = 0, details = 0, patches = 0;
  Object? failure, detailFailure, patchFailure;
  User? latest;
  UserRolesWriteReceipt? receipt;
  List<String>? sentRoles;
  String? sentId;
  Future<List<User>> Function()? reading;
  Future<User> Function()? checking;
  Future<UserRolesWriteReceipt> Function()? writing;
  @override
  Future<List<User>> getAll() async {
    lists++;
    if (failure != null) throw failure!;
    return reading == null ? users : reading!();
  }

  @override
  Future<User> getById(String id) async {
    details++;
    if (detailFailure != null) throw detailFailure!;
    return checking == null
        ? latest ?? users.firstWhere((u) => u.id == id)
        : checking!();
  }

  @override
  Future<UserRolesWriteReceipt> updateRoles(
    String id,
    List<String> roles,
  ) async {
    patches++;
    sentId = id;
    sentRoles = roles;
    if (patchFailure != null) throw patchFailure!;
    return writing == null
        ? receipt ??
              UserRolesWriteReceipt(
                id: id,
                user: user(id: id, role: roles.single),
              )
        : writing!();
  }
}

Dio mockDio(Object? Function(RequestOptions) response, {List<String>? paths}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (request, handler) {
        paths?.add('${request.method} ${request.path}');
        try {
          final body = response(request);
          handler.resolve(
            Response(
              requestOptions: request,
              data: body is Uint8List ? body : jsonDecode(jsonEncode(body)),
              statusCode: 200,
            ),
          );
        } catch (e) {
          handler.reject(
            e is DioException
                ? e
                : DioException(requestOptions: request, error: e),
          );
        }
      },
    ),
  );
  addTearDown(dio.close);
  return dio;
}

DioException httpFailure(int code) => DioException(
  requestOptions: RequestOptions(path: '/users'),
  type: DioExceptionType.badResponse,
  response: Response(
    requestOptions: RequestOptions(path: '/users'),
    statusCode: code,
    data: {'message': 'Rechazo simulado $code'},
  ),
);
