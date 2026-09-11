enum AlertSeverity { low, medium, high, critical }

extension AlertSeverityX on AlertSeverity {
  String get wireValue => switch (this) {
    AlertSeverity.low => 'LOW',
    AlertSeverity.medium => 'MEDIUM',
    AlertSeverity.high => 'HIGH',
    AlertSeverity.critical => 'CRITICAL',
  };

  String get label => switch (this) {
    AlertSeverity.low => 'Baja',
    AlertSeverity.medium => 'Moderada',
    AlertSeverity.high => 'Alta',
    AlertSeverity.critical => 'Crítica',
  };

  static AlertSeverity fromWire(String value) => switch (value) {
    'MEDIUM' || 'MODERATE' => AlertSeverity.medium,
    'HIGH' => AlertSeverity.high,
    'CRITICAL' => AlertSeverity.critical,
    _ => AlertSeverity.low,
  };
}

enum AlertStatus { open, attended, closed }

extension AlertStatusX on AlertStatus {
  String get wireValue => switch (this) {
    AlertStatus.open => 'OPEN',
    AlertStatus.attended => 'ATTENDED',
    AlertStatus.closed => 'CLOSED',
  };

  String get label => switch (this) {
    AlertStatus.open => 'Activa',
    AlertStatus.attended => 'Atendida',
    AlertStatus.closed => 'Cerrada',
  };

  static AlertStatus fromWire(String value) => switch (value) {
    'ATTENDED' || 'ACKNOWLEDGED' => AlertStatus.attended,
    'CLOSED' || 'RESOLVED' => AlertStatus.closed,
    _ => AlertStatus.open,
  };
}

class AlertType {
  AlertType._();

  static const cardiac = 'CARDIAC';
  static const respiratory = 'RESPIRATORY';
  static const neurological = 'NEUROLOGICAL';
  static const fall = 'FALL';
  static const medication = 'MEDICATION';
  static const other = 'OTHER';

  static const values = [
    cardiac,
    respiratory,
    neurological,
    fall,
    medication,
    other,
  ];

  static String label(String type) => switch (type) {
    cardiac => 'Alerta cardiaca',
    respiratory => 'Alerta respiratoria',
    neurological => 'Alerta neurológica',
    fall => 'Riesgo de caída',
    medication => 'Alerta de medicación',
    _ => 'Alerta clínica',
  };
}

class Alert {
  const Alert({
    required this.id,
    required this.patientId,
    required this.type,
    required this.severity,
    required this.description,
    required this.status,
    required this.triggeredBy,
    required this.triggeredAt,
    this.attendedBy,
    this.attendedAt,
    this.closedBy,
    this.resolutionNotes,
    this.closedAt,
  });

  final String id;
  final String patientId;
  final String type;
  final AlertSeverity severity;
  final String description;
  final AlertStatus status;
  final String triggeredBy;
  final DateTime triggeredAt;
  final String? attendedBy;
  final DateTime? attendedAt;
  final String? closedBy;
  final String? resolutionNotes;
  final DateTime? closedAt;

  factory Alert.fromJson(Map<String, dynamic> json) {
    // AlertResource has no createdAt/triggeredAt field at all — mirrors
    // alert-assembler.ts's fallback chain (triggeredAt ?? attendedAt ??
    // closedAt ?? now), which avoids crashing on every single alert.
    final triggeredAtRaw =
        json['triggeredAt'] ?? json['attendedAt'] ?? json['closedAt'];
    final triggeredAt = triggeredAtRaw != null
        ? DateTime.tryParse(triggeredAtRaw as String) ?? DateTime.now()
        : DateTime.now();

    return Alert(
      id: json['id'].toString(),
      patientId: json['patientId'].toString(),
      type: json['type'] as String,
      severity: AlertSeverityX.fromWire(json['severity'] as String),
      description: json['description'] as String,
      status: AlertStatusX.fromWire(json['status'] as String),
      triggeredBy: json['triggeredBy'] as String,
      triggeredAt: triggeredAt,
      attendedBy: json['attendedBy'] as String?,
      attendedAt: json['attendedAt'] != null
          ? DateTime.tryParse(json['attendedAt'] as String)
          : null,
      closedBy: json['closedBy'] as String?,
      resolutionNotes: json['resolutionNotes'] as String?,
      closedAt: json['closedAt'] != null
          ? DateTime.tryParse(json['closedAt'] as String)
          : null,
    );
  }

  String get title => AlertType.label(type);

  String get message => description;

  String get severityLabel => severity.label;

  String get statusLabel => status.label;

  bool get isCritical => severity == AlertSeverity.critical;

  bool get isActive => status != AlertStatus.closed;
}
