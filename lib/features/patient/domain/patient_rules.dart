import '../../iam/domain/user.dart';
import 'patient.dart';

class PatientRules {
  PatientRules._();

  static const genders = {
    'Male': 'Masculino',
    'Female': 'Femenino',
    'Other': 'Otro',
  };

  static DateTime day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String? text(String? value, String label, int max) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '$label es obligatorio.';
    if (trimmed.length > max) return '$label admite hasta $max caracteres.';
    return null;
  }

  static String? name(String? value, String label) {
    final error = text(value, label, 80);
    if (error != null) return error;

    return RegExp(r'^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ ]+$').hasMatch(value!.trim())
        ? null
        : '$label solo admite letras y espacios.';
  }

  static String? document(String? value) =>
      RegExp(r'^\d{8,20}$').hasMatch(value?.trim() ?? '')
      ? null
      : 'El documento debe tener entre 8 y 20 dígitos.';

  static String? birth(DateTime? value, {DateTime? today}) {
    if (value == null) return 'Selecciona la fecha de nacimiento.';

    if (day(value).isBefore(DateTime(1930)) ||
        day(value).isAfter(day(today ?? DateTime.now()))) {
      return 'El nacimiento debe estar entre 01/01/1930 y hoy.';
    }

    return null;
  }

  static String? admission(DateTime? value, {DateTime? today}) {
    if (value == null) return 'Selecciona la fecha de ingreso.';

    return day(value).isAfter(day(today ?? DateTime.now()))
        ? 'La fecha de ingreso no puede ser futura.'
        : null;
  }

  static RegisterPatientCommand validate(
    RegisterPatientCommand c, {
    DateTime? today,
  }) {
    final admissionDate = c.admissionDate ?? today ?? DateTime.now();

    final errors = [
      name(c.firstName, 'Nombre'),
      name(c.lastName, 'Apellido'),
      document(c.documentNumber),
      birth(c.birthDate, today: today),
      genders.containsKey(c.gender.trim())
          ? null
          : 'Selecciona un género válido.',
      text(c.diagnosis, 'Diagnóstico', 180),
      text(c.roomNumber, 'Habitación', 20),
      text(c.bedNumber, 'Cama', 20),
      text(c.attendingPhysician, 'Médico tratante', 120),
      admission(admissionDate, today: today),
    ];

    for (final error in errors) {
      if (error != null) throw FormatException(error);
    }

    return RegisterPatientCommand(
      firstName: c.firstName.trim(),
      lastName: c.lastName.trim(),
      documentNumber: c.documentNumber.trim(),
      birthDate: day(c.birthDate),
      gender: c.gender.trim(),
      diagnosis: c.diagnosis.trim(),
      roomNumber: c.roomNumber.trim(),
      bedNumber: c.bedNumber.trim(),
      attendingPhysician: c.attendingPhysician.trim(),
      status: c.status,
      admissionDate: day(admissionDate),
    );
  }

  static bool duplicate(
    Iterable<Patient> patients,
    String document, {
    String? excludingId,
  }) => patients.any(
    (p) => p.id != excludingId && p.documentNumber.trim() == document.trim(),
  );

  static bool matches(Patient p, String query) =>
      '${p.code} ${p.fullName} ${p.documentNumber} ${p.roomNumber} ${p.bedNumber} ${p.statusLabel} ${p.diagnosis}'
          .toLowerCase()
          .contains(query.trim().toLowerCase());

  static bool inPeriod(DateTime date, {DateTime? from, DateTime? to}) {
    final localDay = day(date.toLocal());

    return (from == null || !localDay.isBefore(day(from))) &&
        (to == null || !localDay.isAfter(day(to)));
  }
}

class PatientPermissions {
  const PatientPermissions(this.roles);

  final List<String> roles;

  bool get read => roles.any([kRoleAdmin, kRoleDoctor, kRoleNurse].contains);

  bool get create => roles.any([kRoleAdmin, kRoleNurse].contains);

  bool get update => roles.any([kRoleAdmin, kRoleDoctor, kRoleNurse].contains);

  bool get delete => roles.contains(kRoleAdmin);
}
