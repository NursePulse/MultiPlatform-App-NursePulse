import 'package:dio/dio.dart';
import 'package:nurse_pulse_app/features/patient/domain/patient.dart';
import 'package:nurse_pulse_app/features/patient/infrastructure/patient_api.dart';

import 'fixtures.dart';

class FakePatientApi extends PatientApi {
  FakePatientApi() : super(Dio());

  List<Patient> patients = [];
  Future<List<Patient>> Function()? loading;
  Future<Patient> Function(RegisterPatientCommand)? creating;
  Object? failure;
  int writes = 0;
  RegisterPatientCommand? lastCommand;

  @override
  Future<List<Patient>> getAll() async {
    if (failure != null) throw failure!;
    return loading == null ? patients : await loading!();
  }

  @override
  Future<Patient> create(RegisterPatientCommand c) async {
    writes++;
    lastCommand = c;
    if (failure != null) throw failure!;
    return creating == null ? patientFrom(c) : await creating!(c);
  }

  @override
  Future<Patient> update(String id, RegisterPatientCommand c) async {
    writes++;
    lastCommand = c;
    if (failure != null) throw failure!;
    return patientFrom(c, id: id);
  }

  @override
  Future<void> delete(String id) async {
    writes++;
    if (failure != null) throw failure!;
  }
}
