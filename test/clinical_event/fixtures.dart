import 'package:dio/dio.dart';
import 'package:nurse_pulse_app/features/clinical_event/domain/clinical_event.dart';
import 'package:nurse_pulse_app/features/clinical_event/infrastructure/clinical_event_api.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';

const actor = User(id: '2', username: 'staff.test', roles: [kRoleNurse]);

RegisterClinicalEventCommand command({
  String patientId = '1',
  String type = 'OBSERVATION',
  String severity = 'LOW',
  String title = ' Control ',
  String description = ' Observación ficticia ',
}) => RegisterClinicalEventCommand(
  patientId: patientId,
  eventType: type,
  severity: severity,
  title: title,
  description: description,
);

ClinicalEvent eventFrom(
  RegisterClinicalEventCommand c, {
  String id = '1',
  DateTime? date,
}) => ClinicalEvent(
  id: id,
  patientId: c.patientId,
  eventType: c.eventType,
  severity: c.severity,
  title: c.title,
  description: c.description,
  registeredBy: actor.username,
  occurredAt: date ?? DateTime(2026, 10, 4, 12),
);

class FakeEventApi extends ClinicalEventApi {
  FakeEventApi() : super(Dio());
  List<ClinicalEvent> events = [];
  int writes = 0, reads = 0;
  Object? failure;
  RegisterClinicalEventCommand? sent;
  Future<ClinicalEvent> Function(RegisterClinicalEventCommand)? writing;
  Future<List<ClinicalEvent>> Function()? loading;

  @override
  Future<List<ClinicalEvent>> getAll() async {
    reads++;
    if (failure != null) throw failure!;
    return loading == null ? events : loading!();
  }

  @override
  Future<List<ClinicalEvent>> getByPatientId(String id) async =>
      (await getAll()).where((e) => e.patientId == id).toList();
  @override
  Future<ClinicalEvent> register(RegisterClinicalEventCommand c) async {
    writes++;
    sent = c;
    if (failure != null) throw failure!;
    return writing == null ? eventFrom(c) : writing!(c);
  }
}

DioException httpFailure(int status) => DioException(
  requestOptions: RequestOptions(path: '/clinical-events'),
  type: DioExceptionType.badResponse,
  response: Response(
    requestOptions: RequestOptions(path: '/clinical-events'),
    statusCode: status,
    data: {'message': 'Rechazo simulado $status'},
  ),
);
