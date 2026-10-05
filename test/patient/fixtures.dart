import 'package:nurse_pulse_app/features/patient/domain/patient.dart';

RegisterPatientCommand patientCommand({
  String document = '00123456',
  String first = ' Ana ',
  String gender = 'Female',
  DateTime? birth,
  DateTime? admission,
}) => RegisterPatientCommand(
  firstName: first,
  lastName: ' López ',
  documentNumber: document,
  birthDate: birth ?? DateTime(2000, 2, 15),
  gender: gender,
  diagnosis: ' Control ',
  roomNumber: ' A-1 ',
  bedNumber: ' 2 ',
  attendingPhysician: ' Dra. Soto ',
  admissionDate: admission ?? DateTime(2025, 1, 1),
  status: PatientStatus.observation,
);

Patient patientFrom(RegisterPatientCommand c, {String id = '1'}) =>
    Patient.fromJson({'id': id, ...c.toJson()});
