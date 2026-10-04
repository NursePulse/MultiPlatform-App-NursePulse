import '../../iam/domain/user.dart';
import 'clinical_event.dart';

class ClinicalEventRules {
  ClinicalEventRules._();

  static bool canRegister(List<String> roles) =>
      roles.any([kRoleNurse, kRoleDoctor, kRoleAdmin].contains);

  static String? patient(String? value) {
    final text = value?.trim() ?? '';
    final number = int.tryParse(text);
    return RegExp(r'^[0-9]+$').hasMatch(text) && number != null && number > 0
        ? null
        : 'Selecciona un paciente válido.';
  }

  static String? text(String? value, String label, int min, int max) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '$label es obligatorio.';
    if (trimmed.length < min || trimmed.length > max) {
      return '$label debe tener entre $min y $max caracteres.';
    }
    return null;
  }

  static String? type(String? value) =>
      ClinicalEventType.values.contains(value?.trim())
      ? null
      : 'Selecciona un tipo de evento válido.';

  static String? severity(String? value) =>
      ClinicalEventSeverity.values.contains(value?.trim())
      ? null
      : 'Selecciona una severidad válida.';

  static RegisterClinicalEventCommand validate(RegisterClinicalEventCommand c) {
    for (final error in [
      patient(c.patientId),
      type(c.eventType),
      severity(c.severity),
      text(c.title, 'Título', 4, 120),
      text(c.description, 'Descripción', 10, 1000),
    ]) {
      if (error != null) throw FormatException(error);
    }
    return RegisterClinicalEventCommand(
      patientId: int.parse(c.patientId.trim()).toString(),
      eventType: c.eventType.trim(),
      severity: c.severity.trim(),
      title: c.title.trim(),
      description: c.description.trim(),
    );
  }

  static bool needsAlert(ClinicalEvent event) => [
    ClinicalEventSeverity.high,
    ClinicalEventSeverity.critical,
  ].contains(event.severity);

  static String alertDescription(ClinicalEvent event) {
    final heading = event.isCritical
        ? 'Evento clínico crítico'
        : 'Evento clínico de alto riesgo';
    final description =
        '$heading: ${event.eventType}: ${event.title}. ${event.description}';
    if (description.length <= 255) return description;
    var end = 254;
    // No cortar un par de sustitutos UTF-16 al resumir la alerta.
    final last = description.codeUnitAt(end - 1);
    if (last >= 0xD800 && last <= 0xDBFF) end--;
    return '${description.substring(0, end)}…';
  }
}
