import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audit/application/audit_register.dart';
import '../../audit/domain/audit_log.dart';
import '../../audit/infrastructure/audit_api.dart';
import '../../clinical_event/domain/clinical_event.dart';
import '../../clinical_event/infrastructure/clinical_event_api.dart';
import '../../notification/domain/alert.dart';
import '../../notification/infrastructure/alert_api.dart';
import '../../patient/infrastructure/patient_api.dart';
import '../../sbar/domain/sbar_transfer.dart';
import '../../sbar/infrastructure/sbar_api.dart';
import '../../vital_sign/domain/vital_sign.dart';
import '../../vital_sign/infrastructure/vital_sign_api.dart';
import '../domain/report.dart';
import '../infrastructure/report_api.dart';

class ReportState {
  const ReportState({this.reports = const [], this.loading = false, this.error});

  final List<Report> reports;
  final bool loading;
  final String? error;

  ReportState copyWith({List<Report>? reports, bool? loading, String? error}) =>
      ReportState(
        reports: reports ?? this.reports,
        loading: loading ?? this.loading,
        error: error,
      );
}

/// Aggregates live clinical data client-side for the requested period, then
/// persists the consolidated summary through the real `/api/v1/reports` API
/// — mirrors ReportStore.generateReport()/loadReports() in the Angular app.
class ReportNotifier extends StateNotifier<ReportState> {
  ReportNotifier(this._ref) : super(const ReportState());

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final reports = await _ref.read(reportApiProvider).getAll();
      reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = state.copyWith(reports: reports, loading: false);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'No se pudieron cargar los reportes.',
      );
    }
  }

  Future<Report> generate({
    required String type,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final patients = await _ref.read(patientApiProvider).getAll();

    final sbarGroups = await Future.wait(
      patients.map(
        (p) => _ref
            .read(sbarApiProvider)
            .getByPatientId(p.id)
            .catchError((_) => const <SbarTransfer>[]),
      ),
    );
    final sbarTransfers = sbarGroups.expand((t) => t).toList();

    final vitalSigns = await _ref
        .read(vitalSignApiProvider)
        .getAll()
        .catchError((_) => const <VitalSign>[]);
    final clinicalEvents = await _ref
        .read(clinicalEventApiProvider)
        .getAll()
        .catchError((_) => const <ClinicalEvent>[]);
    final alerts = await _ref
        .read(alertApiProvider)
        .getAll()
        .catchError((_) => const <Alert>[]);
    final auditLogs = await _ref
        .read(auditApiProvider)
        .getAll()
        .catchError((_) => const <AuditLog>[]);

    bool inRange(DateTime value) =>
        !value.isBefore(startDate) && !value.isAfter(endDate);

    final vitalsInRange = vitalSigns
        .where((v) => inRange(v.recordedAt))
        .length;
    final eventsInRange = clinicalEvents
        .where((e) => inRange(e.occurredAt))
        .length;
    final sbarInRange = sbarTransfers
        .where((s) => s.transferredAt == null || inRange(s.transferredAt!))
        .length;
    final auditInRange = auditLogs
        .where((a) => inRange(a.performedAt))
        .length;
    // AlertResource has no triggeredAt/createdAt field on the backend at
    // all, so Alert.triggeredAt is always a client-side fallback (attendedAt
    // ?? closedAt ?? DateTime.now() — see alert.dart), never a real trigger
    // time. Filtering by it would silently exclude/include alerts based on
    // that synthetic value instead of the period the user picked. Mirrors
    // report.store.ts, which hits the same missing-field gap and — since the
    // raw API field is always absent — ends up counting every alert
    // regardless of period rather than filtering by a fabricated date.
    final alertsInRange = alerts;
    final activeAlerts = alertsInRange
        .where((a) => a.status != AlertStatus.closed)
        .length;
    final criticalAlerts = alertsInRange
        .where(
          (a) => a.severity == AlertSeverity.critical &&
              a.status != AlertStatus.closed,
        )
        .length;

    final summary = ReportSummary(
      patients: patients.length,
      vitalSigns: vitalsInRange,
      clinicalEvents: eventsInRange,
      sbarTransfers: sbarInRange,
      activeAlerts: activeAlerts,
      criticalAlerts: criticalAlerts,
      auditLogs: auditInRange,
    );

    final command = CreateReportCommand(
      type: type,
      title: title,
      startDate: startDate,
      endDate: endDate,
      summary: summary,
      clinicalConclusion: _buildConclusion(
        vitalsInRange,
        sbarInRange,
        activeAlerts,
        criticalAlerts,
      ),
    );

    final created = await _ref.read(reportApiProvider).generate(command);
    state = state.copyWith(reports: [created, ...state.reports]);

    registerAudit(
      _ref,
      entityType: 'REPORT',
      entityId: created.id,
      actionType: 'REPORT_GENERATED',
    );
    return created;
  }

  String _buildConclusion(
    int vitalSigns,
    int sbarTransfers,
    int activeAlerts,
    int criticalAlerts,
  ) {
    if (criticalAlerts > 0) {
      return 'Se detectaron $criticalAlerts alerta(s) crítica(s). '
          'Requiere revisión médica prioritaria.';
    }
    if (activeAlerts > 0) {
      return 'Existen $activeAlerts alerta(s) activa(s). '
          'Mantener seguimiento del turno.';
    }
    if (vitalSigns > 0 || sbarTransfers > 0) {
      return 'Periodo con actividad clínica registrada y sin alertas '
          'críticas activas.';
    }
    return 'No se encontraron movimientos clínicos relevantes en el '
        'periodo seleccionado.';
  }
}

final reportNotifierProvider =
    StateNotifierProvider<ReportNotifier, ReportState>(
      (ref) => ReportNotifier(ref),
    );
