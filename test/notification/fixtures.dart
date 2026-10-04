import 'package:dio/dio.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/notification/domain/alert.dart';
import 'package:nurse_pulse_app/features/notification/infrastructure/alert_api.dart';

const nurse = User(id: '2', username: 'nurse.test', roles: [kRoleNurse]);
const doctor = User(id: '3', username: 'doctor.test', roles: [kRoleDoctor]);
const admin = User(id: '4', username: 'admin.test', roles: [kRoleAdmin]);

Map<String, dynamic> alertJson({
  String id = '9',
  String patientId = '1',
  String status = 'OPEN',
  String severity = 'CRITICAL',
  String? date = '2026-10-04T12:00:00',
  String? attendedBy,
  String? closedBy,
}) => {
  'id': int.parse(id),
  'patientId': int.parse(patientId),
  'type': 'CARDIAC',
  'severity': severity,
  'description': 'Alerta ficticia',
  'status': status,
  'triggeredBy': 'Equipo clínico',
  'triggeredAt': date,
  'attendedBy': attendedBy,
  'attendedAt': attendedBy == null ? null : '2026-10-04T12:01:00',
  'closedBy': closedBy,
  'closedAt': closedBy == null ? null : '2026-10-04T12:02:00',
  'resolutionNotes': closedBy == null
      ? null
      : 'Alerta cerrada desde seguimiento clínico.',
};

Alert alert({
  String id = '9',
  String status = 'OPEN',
  String severity = 'CRITICAL',
  String? date = '2026-10-04T12:00:00',
}) => Alert.fromJson(
  alertJson(id: id, status: status, severity: severity, date: date),
);

class FakeAlertApi extends AlertApi {
  FakeAlertApi() : super(Dio());
  List<Alert> alerts = [];
  Alert? current;
  int posts = 0, attends = 0, closes = 0, reads = 0, detailReads = 0;
  int get writes => posts + attends + closes;
  Map<String, Object>? sent;
  Object? failure, readFailure, detailFailure;
  AlertWriteReceipt? receipt;
  Future<AlertWriteReceipt> Function()? writing;
  Future<Alert> Function()? detail;
  Future<List<Alert>> Function()? loading;

  @override
  Future<List<Alert>> getAll() async {
    reads++;
    if (readFailure != null) throw readFailure!;
    return loading == null ? alerts : loading!();
  }

  @override
  Future<List<Alert>> getByPatientId(String id) async =>
      (await getAll()).where((a) => a.patientId == id).toList();
  @override
  Future<Alert> getById(String id) async {
    detailReads++;
    if (detailFailure != null) throw detailFailure!;
    return detail == null ? current ?? alert(id: id) : detail!();
  }

  Future<AlertWriteReceipt> _write(AlertStatus status) async {
    if (failure != null) throw failure!;
    return writing == null
        ? receipt ??
              AlertWriteReceipt(
                id: '9',
                alert: alert(status: status.wireValue),
              )
        : writing!();
  }

  @override
  Future<AlertWriteReceipt> create({
    required String patientId,
    required String type,
    required AlertSeverity severity,
    required String description,
    required String triggeredBy,
  }) {
    posts++;
    sent = {
      'patientId': patientId,
      'type': type,
      'severity': severity.wireValue,
      'description': description,
      'triggeredBy': triggeredBy,
    };
    return _write(AlertStatus.open);
  }

  @override
  Future<AlertWriteReceipt> attend(
    String id,
    String attendedBy, {
    String? patientId,
  }) {
    attends++;
    sent = {'id': id, 'attendedBy': attendedBy};
    return _write(AlertStatus.attended);
  }

  @override
  Future<AlertWriteReceipt> close(
    String id,
    String closedBy, {
    String? patientId,
    String resolutionNotes = 'Alerta cerrada desde seguimiento clínico.',
  }) {
    closes++;
    sent = {'id': id, 'closedBy': closedBy, 'resolutionNotes': resolutionNotes};
    return _write(AlertStatus.closed);
  }
}

DioException httpFailure(int status) => DioException(
  requestOptions: RequestOptions(path: '/alerts'),
  type: DioExceptionType.badResponse,
  response: Response(
    requestOptions: RequestOptions(path: '/alerts'),
    statusCode: status,
    data: {'message': 'Rechazo simulado $status'},
  ),
);
