import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../audit/application/audit_register.dart';
import '../domain/clinical_event.dart';
import '../infrastructure/clinical_event_api.dart';

class ClinicalEventState {
  const ClinicalEventState({
    this.events = const [],
    this.loading = false,
    this.error,
  });

  final List<ClinicalEvent> events;
  final bool loading;
  final String? error;

  ClinicalEventState copyWith({
    List<ClinicalEvent>? events,
    bool? loading,
    String? error,
  }) => ClinicalEventState(
    events: events ?? this.events,
    loading: loading ?? this.loading,
    error: error,
  );
}

class ClinicalEventNotifier extends StateNotifier<ClinicalEventState> {
  ClinicalEventNotifier(this._api, this._ref) : super(const ClinicalEventState());

  final ClinicalEventApi _api;
  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final events = await _api.getAll();
      state = state.copyWith(events: events, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: describeDioError(e));
    }
  }

  Future<List<ClinicalEvent>> loadForPatient(String patientId) =>
      _api.getByPatientId(patientId);

  Future<ClinicalEvent> register(RegisterClinicalEventCommand command) async {
    final created = await _api.register(command);
    state = state.copyWith(events: [created, ...state.events]);
    registerAudit(
      _ref,
      entityType: 'CLINICAL_EVENT',
      entityId: created.id,
      actionType: 'CREATE',
      patientId: created.patientId,
    );
    return created;
  }
}

final clinicalEventNotifierProvider =
    StateNotifierProvider<ClinicalEventNotifier, ClinicalEventState>(
      (ref) => ClinicalEventNotifier(ref.watch(clinicalEventApiProvider), ref),
    );
