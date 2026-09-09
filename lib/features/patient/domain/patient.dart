enum PatientStatus { stable, observation, critical, discharged }

extension PatientStatusX on PatientStatus {
  String get wireValue => switch (this) {
    PatientStatus.stable => 'STABLE',
    PatientStatus.observation => 'OBSERVATION',
    PatientStatus.critical => 'CRITICAL',
    PatientStatus.discharged => 'DISCHARGED',
  };

  String get label => switch (this) {
    PatientStatus.stable => 'Estable',
    PatientStatus.observation => 'En observación',
    PatientStatus.critical => 'Crítico',
    PatientStatus.discharged => 'Alta',
  };

  static PatientStatus fromWire(String value) => switch (value) {
    'OBSERVATION' => PatientStatus.observation,
    'CRITICAL' => PatientStatus.critical,
    'DISCHARGED' => PatientStatus.discharged,
    _ => PatientStatus.stable,
  };
}

class Patient {
  const Patient({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.documentNumber,
    required this.birthDate,
    required this.gender,
    required this.diagnosis,
    required this.roomNumber,
    required this.bedNumber,
    required this.attendingPhysician,
    required this.status,
    required this.admissionDate,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String documentNumber;
  final DateTime birthDate;
  final String gender;
  final String diagnosis;
  final String roomNumber;
  final String bedNumber;
  final String attendingPhysician;
  final PatientStatus status;
  final DateTime admissionDate;

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
    id: json['id'].toString(),
    firstName: json['firstName'] as String,
    lastName: json['lastName'] as String,
    documentNumber: json['documentNumber'] as String,
    birthDate: DateTime.parse(json['birthDate'] as String),
    gender: json['gender'] as String,
    diagnosis: json['diagnosis'] as String,
    roomNumber: json['roomNumber'] as String,
    bedNumber: json['bedNumber'] as String,
    attendingPhysician: json['attendingPhysician'] as String,
    status: PatientStatusX.fromWire(json['status'] as String),
    admissionDate: DateTime.parse(json['admissionDate'] as String),
  );

  String get code => 'P${id.padLeft(3, '0')}';

  String get fullName => '$firstName $lastName';

  /// Mirrors `p.firstName.charAt(0) + p.lastName.charAt(0)` in the Angular
  /// app's patient list.
  String get initials {
    final first = firstName.isNotEmpty ? firstName[0] : '';
    final last = lastName.isNotEmpty ? lastName[0] : '';
    return '$first$last'.toUpperCase();
  }

  String get statusLabel => status.label;

  int get age {
    final today = DateTime.now();
    var age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  bool get requiresMonitoring =>
      status != PatientStatus.stable && status != PatientStatus.discharged;
}

class RegisterPatientCommand {
  const RegisterPatientCommand({
    required this.firstName,
    required this.lastName,
    required this.documentNumber,
    required this.birthDate,
    required this.gender,
    required this.diagnosis,
    required this.roomNumber,
    required this.bedNumber,
    required this.attendingPhysician,
    this.status = PatientStatus.stable,
    this.admissionDate,
  });

  final String firstName;
  final String lastName;
  final String documentNumber;
  final DateTime birthDate;
  final String gender;
  final String diagnosis;
  final String roomNumber;
  final String bedNumber;
  final String attendingPhysician;
  final PatientStatus status;
  final DateTime? admissionDate;

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    'documentNumber': documentNumber,
    'birthDate': _dateOnly(birthDate),
    'gender': gender,
    'diagnosis': diagnosis,
    'roomNumber': roomNumber,
    'bedNumber': bedNumber,
    'attendingPhysician': attendingPhysician,
    'status': status.wireValue,
    'admissionDate': _dateOnly(admissionDate ?? DateTime.now()),
  };

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
