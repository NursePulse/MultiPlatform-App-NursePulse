/// Backend keys (`ClinicalEventType` enum in `BackendNursePulse`) mapped to
/// their Spanish display label. The key, not the label, must travel over the
/// wire — the backend does `ClinicalEventType.valueOf(eventType.toUpperCase())`.
class ClinicalEventType {
  ClinicalEventType._();

  static const medication = 'MEDICATION';
  static const procedure = 'PROCEDURE';
  static const conditionChange = 'CONDITION_CHANGE';
  static const complication = 'COMPLICATION';
  static const emergency = 'EMERGENCY';
  static const observation = 'OBSERVATION';

  static const values = [
    medication,
    procedure,
    conditionChange,
    complication,
    emergency,
    observation,
  ];

  static const _labels = {
    medication: 'Medicación administrada',
    procedure: 'Procedimiento realizado',
    conditionChange: 'Cambio de condición',
    complication: 'Complicación',
    emergency: 'Emergencia',
    observation: 'Observación',
  };

  static String labelFor(String key) => _labels[key] ?? key;
}

/// Backend keys (`ClinicalEventSeverity` enum) mapped to their Spanish label.
class ClinicalEventSeverity {
  ClinicalEventSeverity._();

  static const low = 'LOW';
  static const moderate = 'MODERATE';
  static const high = 'HIGH';
  static const critical = 'CRITICAL';

  static const values = [low, moderate, high, critical];

  static const _labels = {
    low: 'Bajo',
    moderate: 'Moderado',
    high: 'Alto',
    critical: 'Crítico',
  };

  static String labelFor(String key) => _labels[key] ?? key;
}

class ClinicalEvent {
  const ClinicalEvent({
    required this.id,
    required this.patientId,
    required this.eventType,
    required this.severity,
    required this.title,
    required this.description,
    required this.registeredBy,
    required this.occurredAt,
  });

  final String id;
  final String patientId;
  final String eventType;
  final String severity;
  final String title;
  final String description;
  final String registeredBy;
  final DateTime occurredAt;

  factory ClinicalEvent.fromJson(Map<String, dynamic> json) => ClinicalEvent(
    id: json['id'].toString(),
    patientId: json['patientId'].toString(),
    eventType: json['eventType'] as String,
    severity: json['severity'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    registeredBy: json['registeredBy'] as String? ?? '',
    occurredAt: DateTime.parse(json['occurredAt'] as String),
  );

  bool get isCritical => severity == ClinicalEventSeverity.critical;
}

class RegisterClinicalEventCommand {
  const RegisterClinicalEventCommand({
    required this.patientId,
    required this.eventType,
    required this.severity,
    required this.title,
    required this.description,
  });

  final String patientId;
  final String eventType;
  final String severity;
  final String title;
  final String description;

  Map<String, dynamic> toJson() => {
    'patientId': int.parse(patientId),
    'eventType': eventType,
    'severity': severity,
    'title': title,
    'description': description,
  };
}
