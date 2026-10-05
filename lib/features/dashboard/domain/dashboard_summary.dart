import '../../audit/domain/audit_log.dart';
import '../../clinical_event/domain/clinical_event.dart';
import '../../notification/domain/alert.dart';
import '../../patient/domain/patient.dart';
import '../../vital_sign/domain/vital_sign.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.monitoredPatients,
    required this.activeAlerts,
    required this.criticalAlerts,
    required this.moderateAlerts,
    required this.clinicalEventsToday,
    required this.inspectionsThisMonth,
    required this.lastUpdate,
    required this.criticalPatients,
    this.auditMovements,
  });

  final int monitoredPatients;
  final int activeAlerts;
  final int criticalAlerts;
  final int moderateAlerts;
  final int clinicalEventsToday;
  final int inspectionsThisMonth;
  final DateTime lastUpdate;
  final int criticalPatients;
  final int? auditMovements;
}

class DashboardData {
  const DashboardData({
    required this.patients,
    required this.alerts,
    required this.events,
    required this.vitals,
    this.audits,
    this.auditError,
  });
  final List<Patient> patients;
  final List<Alert> alerts;
  final List<ClinicalEvent> events;
  final List<VitalSign> vitals;
  final List<AuditLog>? audits;
  final String? auditError;
}
