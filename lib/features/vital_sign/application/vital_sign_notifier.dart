import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../audit/application/audit_register.dart';
import '../domain/vital_sign.dart';
import '../infrastructure/vital_sign_api.dart';

class VitalSignState {
  const VitalSignState({
    this.records = const [],
    this.loading = false,
    this.error,
  });

  final List<VitalSign> records;
  final bool loading;
  final String? error;

  VitalSignState copyWith({
    List<VitalSign>? records,
    bool? loading,
    String? error,
  }) => VitalSignState(
    records: records ?? this.records,
    loading: loading ?? this.loading,
    error: error,
  );
}

class VitalSignNotifier extends StateNotifier<VitalSignState> {
  VitalSignNotifier(this._api, this._ref) : super(const VitalSignState());

  final VitalSignApi _api;
  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final records = await _api.getAll();
      state = state.copyWith(records: records, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: describeDioError(e));
    }
  }

  Future<List<VitalSign>> loadForPatient(String patientId) =>
      _api.getByPatientId(patientId);

  Future<VitalSign> record(RecordVitalSignCommand command) async {
    final created = await _api.record(command);
    state = state.copyWith(records: [created, ...state.records]);
    registerAudit(
      _ref,
      entityType: 'VITAL_SIGNS',
      entityId: created.id,
      actionType: 'VITAL_SIGNS_RECORDED',
      patientId: created.patientId,
    );
    return created;
  }
}

final vitalSignNotifierProvider =
    StateNotifierProvider<VitalSignNotifier, VitalSignState>(
      (ref) => VitalSignNotifier(ref.watch(vitalSignApiProvider), ref),
    );
