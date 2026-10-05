import '../../iam/domain/user.dart';
import 'patient_rules.dart';

class PatientMonitoringRules {
  static bool canRead(List<String> roles) =>
      roles.any([kRoleNurse, kRoleDoctor, kRoleAdmin].contains);

  static String id(String value) {
    final text = value.trim(), number = int.tryParse(value.trim());
    if (!RegExp(r'^\d+$').hasMatch(text) || number == null || number <= 0) {
      throw const FormatException(
        'El ID del paciente debe ser un entero positivo.',
      );
    }
    return number.toString();
  }

  static String? period(
    DateTime? from,
    DateTime? to, {
    required DateTime today,
  }) {
    if (from == null && to == null) return null;
    if (from == null || to == null) {
      return 'Selecciona ambas fechas del periodo.';
    }
    final start = PatientRules.day(from), end = PatientRules.day(to);
    if (end.isBefore(start)) {
      return 'El fin del periodo no puede ser anterior al inicio.';
    }
    if (start.isBefore(DateTime(1930)) ||
        end.isAfter(PatientRules.day(today))) {
      return 'El periodo debe estar entre 01/01/1930 y hoy.';
    }
    return null;
  }
}
