import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../audit/application/audit_register.dart';
import '../domain/alert.dart';
import '../infrastructure/alert_api.dart';

class AlertState {
  const AlertState({this.alerts = const [], this.loading = false, this.error});

  final List<Alert> alerts;
  final bool loading;
  final String? error;

  AlertState copyWith({List<Alert>? alerts, bool? loading, String? error}) =>
      AlertState(
        alerts: alerts ?? this.alerts,
        loading: loading ?? this.loading,
        error: error,
      );
}

class AlertNotifier extends StateNotifier<AlertState> {
  AlertNotifier(this._api, this._ref) : super(const AlertState());

  final AlertApi _api;
  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final alerts = await _api.getAll();
      state = state.copyWith(alerts: alerts, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: describeDioError(e));
    }
  }

  Future<List<Alert>> loadForPatient(String patientId) =>
      _api.getByPatientId(patientId);

  /// Mirrors createManualAlert() in notification.store.ts, including the
  /// hardcoded "Equipo clínico" actor (not the real username).
  Future<Alert> create({
    required String patientId,
    required String type,
    required AlertSeverity severity,
    required String description,
  }) async {
    final alert = await _api.create(
      patientId: patientId,
      type: type,
      severity: severity,
      description: description,
      triggeredBy: 'Equipo clínico',
    );
    state = state.copyWith(alerts: [alert, ...state.alerts]);
    registerAudit(
      _ref,
      entityType: 'ALERT',
      entityId: alert.id,
      actionType: 'ALERT_CREATED',
      patientId: alert.patientId,
    );
    return alert;
  }

  void _replace(Alert updated) {
    state = state.copyWith(
      alerts: [
        for (final alert in state.alerts)
          if (alert.id == updated.id) updated else alert,
      ],
    );
  }

  Future<void> attend(String id, String attendedBy) async {
    final updated = await _api.attend(id, attendedBy);
    _replace(updated);
    registerAudit(
      _ref,
      entityType: 'ALERT',
      entityId: updated.id,
      actionType: 'ALERT_ACKNOWLEDGED',
      patientId: updated.patientId,
    );
  }

  Future<void> close(
    String id,
    String closedBy, {
    String? resolutionNotes,
  }) async {
    final updated = await _api.close(
      id,
      closedBy,
      resolutionNotes:
          resolutionNotes ?? 'Alerta cerrada desde seguimiento clínico.',
    );
    _replace(updated);
    registerAudit(
      _ref,
      entityType: 'ALERT',
      entityId: updated.id,
      actionType: 'UPDATE',
      patientId: updated.patientId,
    );
  }
}

final alertNotifierProvider = StateNotifierProvider<AlertNotifier, AlertState>(
  (ref) => AlertNotifier(ref.watch(alertApiProvider), ref),
);
