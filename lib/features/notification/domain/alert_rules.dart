import '../../iam/domain/user.dart';
import 'alert.dart';

const alertDefaultActor = 'Equipo clínico';
const alertClosingNotes = 'Alerta cerrada desde seguimiento clínico.';

enum AlertFilter { all, critical, moderate }

extension AlertFilterX on AlertFilter {
  String get label => switch (this) {
    AlertFilter.all => 'Todas',
    AlertFilter.critical => 'Críticas',
    AlertFilter.moderate => 'Moderadas',
  };
}

class AlertRules {
  static bool canManage(List<String> roles) =>
      roles.any([kRoleNurse, kRoleDoctor, kRoleAdmin].contains);
  static bool canClose(List<String> roles) =>
      roles.any([kRoleDoctor, kRoleAdmin].contains);

  static String? id(String? value, String label) {
    final text = value?.trim() ?? '';
    final number = int.tryParse(text);
    return !RegExp(r'^\d+$').hasMatch(text) || number == null || number <= 0
        ? 'Selecciona $label válido.'
        : null;
  }

  static String? description(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'La descripción es obligatoria.';
    if (text.length > 255) return 'La descripción admite hasta 255 caracteres.';
    return null;
  }

  static String actor(String value) {
    final text = value.trim();
    if (text.isEmpty || text.length > 120) {
      throw const FormatException('El usuario debe tener 1–120 caracteres.');
    }
    return text;
  }

  static String notes(String value) {
    final text = value.trim();
    if (text.isEmpty || text.length > 255) {
      throw const FormatException('Las notas deben tener 1–255 caracteres.');
    }
    return text;
  }

  static void validateCreate(String patientId, String type, String text) {
    final error = id(patientId, 'un paciente') ?? description(text);
    if (error != null) throw FormatException(error);
    if (!AlertType.values.contains(type)) {
      throw const FormatException('Selecciona un tipo de alerta válido.');
    }
  }

  static List<Alert> filter(Iterable<Alert> alerts, AlertFilter filter) => [
    for (final alert in alerts)
      if (alert.isActive &&
          switch (filter) {
            AlertFilter.all => true,
            AlertFilter.critical => alert.isCritical,
            AlertFilter.moderate => !alert.isCritical,
          })
        alert,
  ];
}
