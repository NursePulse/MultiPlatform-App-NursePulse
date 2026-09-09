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

  factory AuditLog.fromJson(Map<String, dynamic> json) => AuditLog(
    id: json['id'].toString(),
    entityType: json['entityType'] as String,
    entityId: json['entityId'].toString(),
    actionType: json['actionType'] as String,
    performedBy: json['performedBy'] as String,
    performedAt: DateTime.parse(json['performedAt'] as String),
    patientId: json['patientId']?.toString(),
    metadata: json['metadata'],
  );

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
    _ => 'Sistema',
  };
}
