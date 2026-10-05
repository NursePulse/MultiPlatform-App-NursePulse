import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../audit/domain/audit_log.dart';
import '../../audit/infrastructure/audit_api.dart';
import '../../clinical_event/domain/clinical_event.dart';
import '../../clinical_event/infrastructure/clinical_event_api.dart';
import '../../notification/domain/alert.dart';
import '../../notification/infrastructure/alert_api.dart';
import '../../patient/domain/patient.dart';
import '../../patient/infrastructure/patient_api.dart';
import '../../vital_sign/domain/vital_sign.dart';
import '../../vital_sign/infrastructure/vital_sign_api.dart';
import '../domain/dashboard_rules.dart';
import '../domain/dashboard_summary.dart';

class DashboardApi {
  DashboardApi(
    this._patients,
    this._alerts,
    this._events,
    this._vitals,
    this._audit,
  );
  final PatientApi _patients;
  final AlertApi _alerts;
  final ClinicalEventApi _events;
  final VitalSignApi _vitals;
  final AuditApi _audit;

  Future<(List<AuditLog>?, String?)> _readAudit() async {
    try {
      final logs = [...await _audit.getAll()];
      logs.sort((a, b) => b.performedAt.compareTo(a.performedAt));
      return (List<AuditLog>.unmodifiable(logs), null);
    } catch (e) {
      return (null, describeDioError(e));
    }
  }

  Future<DashboardData> getData({required bool includeAudit}) async {
    // No existe /dashboard/summary; se consultan solo contratos existentes.
    final audit = includeAudit ? _readAudit() : Future.value((null, null));
    final results = await Future.wait<Object>([
      _patients.getAll(),
      _alerts.getAll(),
      _events.getAll(),
      _vitals.getAll(),
    ]);
    final auditResult = await audit;
    return DashboardData(
      patients: List<Patient>.unmodifiable(results[0] as List<Patient>),
      alerts: List<Alert>.unmodifiable(
        DashboardRules.sortedAlerts(results[1] as List<Alert>),
      ),
      events: List<ClinicalEvent>.unmodifiable(
        results[2] as List<ClinicalEvent>,
      ),
      vitals: List<VitalSign>.unmodifiable(results[3] as List<VitalSign>),
      audits: auditResult.$1,
      auditError: auditResult.$2,
    );
  }
}

final dashboardApiProvider = Provider(
  (ref) => DashboardApi(
    ref.watch(patientApiProvider),
    ref.watch(alertApiProvider),
    ref.watch(clinicalEventApiProvider),
    ref.watch(vitalSignApiProvider),
    ref.watch(auditApiProvider),
  ),
);
