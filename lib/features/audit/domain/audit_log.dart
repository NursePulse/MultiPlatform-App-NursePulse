import 'dart:convert';

class AuditLog {
  const AuditLog({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.actionType,
    required this.performedBy,
    required this.performedAt,
    this.patientId,
    this.metadata,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String actionType;
  final String performedBy;
  final DateTime performedAt;
  final String? patientId;
  final Object? metadata;

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    String text(String key) {
      final value = json[key];
      if ((value is! String &&
              !(['id', 'entityId'].contains(key) && value is int)) ||
          value.toString().trim().isEmpty) {
        throw FormatException('La auditoría no contiene $key válido.');
      }
      return value.toString().trim();
    }

    final id = text('id');
    final number = int.tryParse(id);
    final date = DateTime.tryParse(text('performedAt'));
    if (!RegExp(r'^\d+$').hasMatch(id) ||
        number == null ||
        number <= 0 ||
        date == null) {
      throw const FormatException(
        'La auditoría no contiene un ID y fecha válidos.',
      );
    }
    return AuditLog(
      id: number.toString(),
      entityType: text('entityType'),
      entityId: text('entityId'),
      actionType: text('actionType'),
      performedBy: text('performedBy'),
      performedAt: date,
      patientId: json['patientId']?.toString(),
      metadata: json['metadata'],
    );
  }

  String get code => 'AL-$id';

  String get description {
    Object? value = metadata;
    if (value is String) {
      final original = value;
      try {
        value = jsonDecode(value);
      } on FormatException {
        return original.trim().isEmpty ? actionLabel : original.trim();
      }
    }
    if (value is Map) {
      for (final key in ['description', 'title', 'message', 'eventType']) {
        final candidate = value[key];
        if (candidate is String && candidate.trim().isNotEmpty) {
          return candidate.trim();
        }
      }
    }
    return '$actionLabel · $entityLabel #$entityId';
  }

  String get actionLabel => switch (actionType) {
    'CREATE' => 'Creación',
    'UPDATE' => 'Actualización',
    'DELETE' => 'Eliminación',
    'VIEW' => 'Consulta',
    'SIGN' => 'Firma',
    'HANDOVER' => 'Traspaso SBAR',
    'ALERT_TRIGGERED' => 'Alerta generada',
    'ALERT_ACKNOWLEDGED' => 'Alerta atendida',
    'ALERT_RESOLVED' => 'Alerta cerrada',
    'VITAL_SIGNS_RECORDED' => 'Registro de signos vitales',
    'CLINICAL_NOTE_ADDED' => 'Nota clínica agregada',
    _ => actionType,
  };

  String get entityLabel => switch (entityType) {
    'PATIENT' => 'Paciente',
    'ALERT' => 'Alerta',
    'VITAL_SIGNS' || 'VITAL_SIGN_RECORD' => 'Signos vitales',
    'CLINICAL_EVENT' => 'Evento clínico',
    'SBAR_HANDOVER' || 'HANDOVER' => 'Traspaso SBAR',
    'REPORT' => 'Reporte',
    'AUDIT_LOG' => 'Auditoría',
    'USER' => 'Usuario',
    'MEDICATION_ORDER' => 'Orden de medicación',
    'CARE_PLAN' => 'Plan de cuidados',
    'SYSTEM' => 'Sistema',
    _ => entityType,
  };
}
