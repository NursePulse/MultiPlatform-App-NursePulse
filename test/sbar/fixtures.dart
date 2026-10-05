import 'package:dio/dio.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/sbar/domain/sbar_transfer.dart';
import 'package:nurse_pulse_app/features/sbar/infrastructure/sbar_api.dart';

const actor = User(id: '2', username: 'nurse.test', roles: [kRoleNurse]);
const receiver = User(id: '3', username: 'receiver.test', roles: [kRoleNurse]);

RegisterSbarCommand command({
  String patientId = '1',
  String? target = '3',
  String title = ' SBAR ficticio ',
  String situation = ' Situación ficticia ',
  String background = ' Antecedentes ficticios ',
  String assessment = ' Evaluación ficticia ',
  String recommendation = ' Recomendación ficticia ',
}) => RegisterSbarCommand(
  patientId: patientId,
  targetNurseId: target,
  title: title,
  situation: situation,
  background: background,
  assessment: assessment,
  recommendation: recommendation,
);

Map<String, dynamic> transferJson({
  String id = '9',
  String patientId = '1',
  String status = 'PENDING',
  String? date = '2026-10-04T12:00:00Z',
  String? incoming,
  String? notes,
}) => {
  'id': int.parse(id),
  'patientId': int.parse(patientId),
  'title': 'SBAR ficticio',
  'situation': 'Situación ficticia',
  'background': 'Antecedentes ficticios',
  'assessment': 'Evaluación ficticia',
  'recommendation': 'Recomendación ficticia',
  'registeredBy': actor.username,
  'targetNurseId': 3,
  'status': status,
  'createdAt': date,
  'incomingNurseId': incoming,
  'additionalNotes': notes,
};

SbarTransfer transfer({
  String id = '9',
  String patientId = '1',
  String status = 'PENDING',
  String? date = '2026-10-04T12:00:00Z',
}) => SbarTransfer.fromJson(
  transferJson(id: id, patientId: patientId, status: status, date: date),
);

class FakeSbarApi extends SbarApi {
  FakeSbarApi() : super(Dio());
  List<SbarTransfer> transfers = [];
  int posts = 0, patches = 0, listReads = 0, detailReads = 0;
  RegisterSbarCommand? sent;
  String? sentNotes;
  Object? failure, detailFailure;
  SbarWriteReceipt? receipt;
  Future<List<SbarTransfer>> Function(String)? listing;
  Future<SbarTransfer> Function(String)? detail;
  Future<SbarWriteReceipt> Function()? writing;

  @override
  Future<List<SbarTransfer>> getByPatientId(String id) async {
    listReads++;
    if (failure != null) throw failure!;
    return listing == null
        ? transfers.where((t) => t.patientId == id).toList()
        : listing!(id);
  }

  @override
  Future<SbarTransfer> getById(String id) async {
    detailReads++;
    if (detailFailure != null) throw detailFailure!;
    if (detail != null) return detail!(id);
    for (final t in transfers) {
      if (t.id == id) return t;
    }
    return transfer(id: id);
  }

  @override
  Future<SbarWriteReceipt> register(RegisterSbarCommand c) async {
    posts++;
    sent = c;
    if (failure != null) throw failure!;
    return writing == null
        ? receipt ?? SbarWriteReceipt(id: '9', transfer: transfer())
        : writing!();
  }

  @override
  Future<SbarWriteReceipt> acknowledge(
    String id, {
    String? additionalNotes,
  }) async {
    patches++;
    sentNotes = additionalNotes;
    if (failure != null) throw failure!;
    return writing == null
        ? receipt ??
              SbarWriteReceipt(
                id: id,
                transfer: SbarTransfer.fromJson(
                  transferJson(
                    id: id,
                    status: 'ACKNOWLEDGED',
                    incoming: actor.id,
                    notes: additionalNotes,
                  ),
                ),
              )
        : writing!();
  }
}

DioException httpFailure(int status) => DioException(
  requestOptions: RequestOptions(path: '/handovers'),
  type: DioExceptionType.badResponse,
  response: Response(
    requestOptions: RequestOptions(path: '/handovers'),
    statusCode: status,
    data: {'message': 'Rechazo simulado $status'},
  ),
);
