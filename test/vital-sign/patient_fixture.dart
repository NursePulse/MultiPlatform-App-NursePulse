import 'package:dio/dio.dart';
import 'package:nurse_pulse_app/features/patient/domain/patient.dart';
import 'package:nurse_pulse_app/features/patient/infrastructure/patient_api.dart';

RegisterPatientCommand patientCommand() => RegisterPatientCommand(
  firstName: 'Ana',
  lastName: 'López',
  documentNumber: '00123456',
  birthDate: DateTime(2000, 2, 15),
  gender: 'Female',
  diagnosis: 'Control',
  roomNumber: 'A-1',
  bedNumber: '2',
  attendingPhysician: 'Dra. Soto',
  admissionDate: DateTime(2025, 1, 1),
  status: PatientStatus.observation,
);

Patient patientFrom(RegisterPatientCommand command, {String id = '1'}) =>
    Patient.fromJson({'id': id, ...command.toJson()});

class FakePatientApi extends PatientApi {
  FakePatientApi() : super(Dio());

  List<Patient> patients = [];

  @override
  Future<List<Patient>> getAll() async => List<Patient>.of(patients);

  @override
  Future<Patient> getById(String id) async =>
      patients.firstWhere((patient) => patient.id == id);

  @override
  Future<Patient> create(RegisterPatientCommand command) async =>
      throw UnsupportedError('Esta prueba solo consulta pacientes.');

  @override
  Future<Patient> update(String id, RegisterPatientCommand command) async =>
      throw UnsupportedError('Esta prueba solo consulta pacientes.');

  @override
  Future<void> delete(String id) async =>
      throw UnsupportedError('Esta prueba solo consulta pacientes.');
}
