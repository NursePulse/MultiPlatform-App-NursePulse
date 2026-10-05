import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/audit/domain/audit_log.dart';
import 'package:nurse_pulse_app/features/audit/infrastructure/audit_api.dart';
import 'package:nurse_pulse_app/features/clinical_event/domain/clinical_event.dart';
import 'package:nurse_pulse_app/features/clinical_event/infrastructure/clinical_event_api.dart';
import 'package:nurse_pulse_app/features/dashboard/domain/dashboard_summary.dart';
import 'package:nurse_pulse_app/features/dashboard/infrastructure/dashboard_api.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/notification/domain/alert.dart';
import 'package:nurse_pulse_app/features/notification/infrastructure/alert_api.dart';
import 'package:nurse_pulse_app/features/patient/domain/patient.dart';
import 'package:nurse_pulse_app/features/patient/infrastructure/patient_api.dart';
import 'package:nurse_pulse_app/features/vital_sign/domain/vital_sign.dart';
import 'package:nurse_pulse_app/features/vital_sign/infrastructure/vital_sign_api.dart';

import '../patient/fixtures.dart';

const nurse = User(id: '2', username: 'nurse.test', roles: [kRoleNurse]);
const doctor = User(id: '3', username: 'doctor.test', roles: [kRoleDoctor]);
const admin = User(id: '4', username: 'admin.test', roles: [kRoleAdmin]);
final now = DateTime(2026, 10, 4, 12);

Patient patient({
  String id = '1',
  PatientStatus status = PatientStatus.observation,
}) => Patient.fromJson({
  'id': id,
  ...patientCommand().toJson(),
  'status': status.wireValue,
});

Map<String, dynamic> vitalJson({
  String id = '8',
  String patientId = '1',
  DateTime? date,
  String risk = 'LOW',
}) => {
  'id': id,
  'patientId': patientId,
  'nurseId': 2,
  'heartRate': 80,
  'respiratoryRate': 16,
  'systolic': 120,
  'diastolic': 80,
  'oxygenSaturation': 98,
  'temperature': 36.5,
  'riskLevel': risk,
  'recordedAt': (date ?? now).toIso8601String(),
};
VitalSign vital({
  String id = '8',
  String patientId = '1',
  DateTime? date,
  String risk = 'LOW',
}) => VitalSign.fromJson(
  vitalJson(id: id, patientId: patientId, date: date, risk: risk),
);

Map<String, dynamic> eventJson({
  String id = '7',
  String patientId = '1',
  DateTime? date,
}) => {
  'id': id,
  'patientId': patientId,
  'eventType': 'OBSERVATION',
  'severity': 'LOW',
  'title': 'Evento ficticio',
  'description': 'Descripción ficticia de prueba',
  'registeredBy': nurse.username,
  'occurredAt': (date ?? now).toIso8601String(),
};
ClinicalEvent event({
  String id = '7',
  String patientId = '1',
  DateTime? date,
}) =>
    ClinicalEvent.fromJson(eventJson(id: id, patientId: patientId, date: date));

Map<String, dynamic> auditJson({String id = '5', DateTime? date}) => {
  'id': id,
  'entityType': 'PATIENT',
  'entityId': '1',
  'actionType': 'VIEW',
  'performedBy': doctor.username,
  'performedAt': (date ?? now).toIso8601String(),
};
AuditLog audit({String id = '5', DateTime? date}) =>
    AuditLog.fromJson(auditJson(id: id, date: date));

DashboardData data({
  List<Patient> patients = const [],
  List<Alert> alerts = const [],
  List<ClinicalEvent> events = const [],
  List<VitalSign> vitals = const [],
  List<AuditLog>? audits,
  String? auditError,
}) => DashboardData(
  patients: patients,
  alerts: alerts,
  events: events,
  vitals: vitals,
  audits: audits,
  auditError: auditError,
);

class FakeDashboardApi extends DashboardApi {
  FakeDashboardApi()
    : super(
        PatientApi(Dio()),
        AlertApi(Dio()),
        ClinicalEventApi(Dio()),
        VitalSignApi(Dio()),
        AuditApi(Dio()),
      );
  DashboardData snapshot = data();
  int reads = 0;
  bool? includeAudit;
  Object? failure;
  Future<DashboardData> Function()? loading;
  @override
  Future<DashboardData> getData({required bool includeAudit}) async {
    reads++;
    this.includeAudit = includeAudit;
    if (failure != null) throw failure!;
    return loading == null ? snapshot : loading!();
  }
}

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
              data: jsonDecode(jsonEncode(response(options))),
              statusCode: options.method == 'POST' ? 201 : 200,
            ),
          );
        } on DioException catch (e) {
          handler.reject(e);
        } catch (e) {
          handler.reject(DioException(requestOptions: options, error: e));
        }
      },
    ),
  );
  addTearDown(dio.close);
  return dio;
}

DioException httpFailure(int code) => DioException(
  requestOptions: RequestOptions(path: '/patients'),
  type: DioExceptionType.badResponse,
  response: Response(
    requestOptions: RequestOptions(path: '/patients'),
    statusCode: code,
    data: {'message': 'Rechazo simulado $code'},
  ),
);
