/// Tipos del reporte local, con etiquetas de la referencia web.
class ReportType {
  ReportType._();

  static const vitalSigns = 'VITAL_SIGNS';
  static const patients = 'PATIENTS';
  static const clinicalEvents = 'CLINICAL_EVENTS';
  static const sbar = 'SBAR';
  static const alerts = 'ALERTS';
  static const audit = 'AUDIT';
  static const general = 'GENERAL';

  static const values = [
    vitalSigns,
    patients,
    clinicalEvents,
    sbar,
    alerts,
    audit,
    general,
  ];

  static const _labels = {
    vitalSigns: 'Signos vitales',
    patients: 'Pacientes',
    clinicalEvents: 'Eventos clínicos',
    sbar: 'Traspasos SBAR',
    alerts: 'Alertas',
    audit: 'Auditoría',
    general: 'General',
  };

  static String labelFor(String key) => _labels[key] ?? key;
}

/// Estado de la generación local; no representa un recurso del backend.
class ReportStatus {
  ReportStatus._();

  static const pending = 'PENDING';
  static const generating = 'GENERATING';
  static const completed = 'COMPLETED';
  static const failed = 'FAILED';

  static const _labels = {
    pending: 'Pendiente',
    generating: 'Generando',
    completed: 'Completado',
    failed: 'Fallido',
  };

  static String labelFor(String key) => _labels[key] ?? key;
}

class ReportSummary {
  const ReportSummary({
    required this.patients,
    required this.vitalSigns,
    required this.clinicalEvents,
    required this.sbarTransfers,
    required this.activeAlerts,
    required this.criticalAlerts,
    required this.auditLogs,
  });

  final int patients;
  final int vitalSigns;
  final int clinicalEvents;
  final int sbarTransfers;
  final int activeAlerts;
  final int criticalAlerts;
  final int auditLogs;

  factory ReportSummary.fromJson(Map<String, dynamic> json) => ReportSummary(
    patients: json['patients'] as int,
    vitalSigns: json['vitalSigns'] as int,
    clinicalEvents: json['clinicalEvents'] as int,
    sbarTransfers: json['sbarTransfers'] as int,
    activeAlerts: json['activeAlerts'] as int,
    criticalAlerts: json['criticalAlerts'] as int,
    auditLogs: json['auditLogs'] as int,
  );

  Map<String, dynamic> toJson() => {
    'patients': patients,
    'vitalSigns': vitalSigns,
    'clinicalEvents': clinicalEvents,
    'sbarTransfers': sbarTransfers,
    'activeAlerts': activeAlerts,
    'criticalAlerts': criticalAlerts,
    'auditLogs': auditLogs,
  };

  int get activityTotal =>
      vitalSigns + clinicalEvents + sbarTransfers + activeAlerts + auditLogs;
}

class Report {
  const Report({
    required this.id,
    required this.type,
    required this.title,
    required this.generatedBy,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdAt,
    this.summary,
    this.clinicalConclusion,
  });

  final String id;
  final String type;
  final String title;
  final String generatedBy;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final DateTime createdAt;
  final ReportSummary? summary;
  final String? clinicalConclusion;

  factory Report.fromJson(Map<String, dynamic> json) => Report(
    id: json['id'].toString(),
    type: json['type'] as String,
    title: json['title'] as String,
    generatedBy: json['generatedBy'] as String,
    startDate: DateTime.parse(json['startDate'] as String),
    endDate: DateTime.parse(json['endDate'] as String),
    status: json['status'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    summary: json['summary'] != null
        ? ReportSummary.fromJson(json['summary'] as Map<String, dynamic>)
        : null,
    clinicalConclusion: json['clinicalConclusion'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'generatedBy': generatedBy,
    'startDate': startDate.toUtc().toIso8601String(),
    'endDate': endDate.toUtc().toIso8601String(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'status': status,
    if (summary != null) 'summary': summary!.toJson(),
    if (clinicalConclusion != null) 'clinicalConclusion': clinicalConclusion,
  };
}
