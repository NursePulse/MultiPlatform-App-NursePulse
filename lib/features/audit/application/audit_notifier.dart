import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../domain/audit_log.dart';
import '../infrastructure/audit_api.dart';

class AuditState {
  const AuditState({
    this.logs = const [],
    this.loading = false,
    this.error,
    this.selectedPatientId,
  });

  final List<AuditLog> logs;
  final bool loading;
  final String? error;

  /// null means the unfiltered, all-patients feed; otherwise the per-patient
  /// timeline. Mirrors AuditStore's `_selectedPatientId` signal.
  final String? selectedPatientId;

  AuditState copyWith({
    List<AuditLog>? logs,
    bool? loading,
    String? error,
    String? selectedPatientId,
    bool clearSelectedPatientId = false,
  }) => AuditState(
    logs: logs ?? this.logs,
    loading: loading ?? this.loading,
    error: error,
    selectedPatientId: clearSelectedPatientId
        ? null
        : (selectedPatientId ?? this.selectedPatientId),
  );
}

class AuditNotifier extends StateNotifier<AuditState> {
  AuditNotifier(this._api) : super(const AuditState());

  final AuditApi _api;

  Future<void> load() async {
    state = state.copyWith(
      loading: true,
      error: null,
      clearSelectedPatientId: true,
    );
    try {
      final logs = await _api.getAll();
      // The all-patients feed has no guaranteed order from the backend;
      // force chronological order (oldest -> newest), same as audit.store.ts.
      logs.sort((a, b) => a.performedAt.compareTo(b.performedAt));
      state = state.copyWith(logs: logs, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: describeDioError(e));
    }
  }

  Future<void> loadForPatient(String patientId) async {
    state = state.copyWith(
      loading: true,
      error: null,
      selectedPatientId: patientId,
    );
    try {
      final logs = await _api.getPatientTimeline(patientId);
      state = state.copyWith(logs: logs, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: describeDioError(e));
    }
  }
}

final auditNotifierProvider = StateNotifierProvider<AuditNotifier, AuditState>(
  (ref) => AuditNotifier(ref.watch(auditApiProvider)),
);
