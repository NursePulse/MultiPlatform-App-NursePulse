import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../notification/domain/alert.dart';
import '../../notification/infrastructure/alert_api.dart';
import '../../patient/domain/patient.dart';
import '../../patient/infrastructure/patient_api.dart';
import '../../clinical_event/infrastructure/clinical_event_api.dart';
import '../../vital_sign/infrastructure/vital_sign_api.dart';
import '../domain/dashboard_summary.dart';
import '../infrastructure/dashboard_api.dart';

class DashboardState {
  const DashboardState({
    this.summary,
    this.loading = false,
    this.error,
    this.isFallback = false,
  });

  final DashboardSummary? summary;
  final bool loading;
  final String? error;

  /// True when the value was computed client-side because the backend has
  /// no /dashboard/summary endpoint.
  final bool isFallback;

  DashboardState copyWith({
    DashboardSummary? summary,
    bool? loading,
    String? error,
    bool? isFallback,
  }) => DashboardState(
    summary: summary ?? this.summary,
    loading: loading ?? this.loading,
    error: error,
    isFallback: isFallback ?? this.isFallback,
  );
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier(this._ref)
    : _dashboardApi = _ref.read(dashboardApiProvider),
      _patientApi = _ref.read(patientApiProvider),
      _alertApi = _ref.read(alertApiProvider),
      _clinicalEventApi = _ref.read(clinicalEventApiProvider),
      _vitalSignApi = _ref.read(vitalSignApiProvider),
      super(const DashboardState());

  // ignore: unused_field
  final Ref _ref;
  final DashboardApi _dashboardApi;
  final PatientApi _patientApi;
  final AlertApi _alertApi;
  final ClinicalEventApi _clinicalEventApi;
  final VitalSignApi _vitalSignApi;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final remote = await _dashboardApi.getSummary();
      if (remote != null) {
        state = state.copyWith(
          summary: remote,
          loading: false,
          isFallback: false,
        );
        return;
      }
      final summary = await _computeFallback();
      state = state.copyWith(
        summary: summary,
        loading: false,
        isFallback: true,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: describeDioError(e));
    }
  }

  Future<DashboardSummary> _computeFallback() async {
    final results = await Future.wait([
      _patientApi.getAll(),
      _alertApi.getAll(),
      _clinicalEventApi.getAll(),
      _vitalSignApi.getAll(),
    ]);
    final patients = results[0] as List<Patient>;
    final alerts = results[1] as List<Alert>;
    final events = results[2] as List;
    final vitals = results[3] as List;

    final now = DateTime.now();
    final activeAlerts = alerts.where((a) => a.isActive).toList();

    return DashboardSummary(
      monitoredPatients: patients
          .where((p) => p.status != PatientStatus.discharged)
          .length,
      activeAlerts: activeAlerts.length,
      criticalAlerts: activeAlerts
          .where((a) => a.severity == AlertSeverity.critical)
          .length,
      // Mirrors dashboard-view.ts's moderateAlertsCount(): every active alert
      // that isn't critical, not just severity == medium.
      moderateAlerts: activeAlerts
          .where((a) => a.severity != AlertSeverity.critical)
          .length,
      clinicalEventsToday: events
          .cast<dynamic>()
          .where(
            (e) =>
                e.occurredAt.year == now.year &&
                e.occurredAt.month == now.month &&
                e.occurredAt.day == now.day,
          )
          .length,
      inspectionsThisMonth: vitals
          .cast<dynamic>()
          .where(
            (v) =>
                v.recordedAt.year == now.year &&
                v.recordedAt.month == now.month,
          )
          .length,
      lastUpdate: now,
    );
  }
}

final dashboardNotifierProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>(
      (ref) => DashboardNotifier(ref),
    );
