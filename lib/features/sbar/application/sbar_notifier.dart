import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audit/application/audit_register.dart';
import '../../patient/application/patient_notifier.dart';
import '../domain/sbar_transfer.dart';
import '../infrastructure/sbar_api.dart';

class SbarState {
  const SbarState({this.transfers = const [], this.loading = false});

  final List<SbarTransfer> transfers;
  final bool loading;

  SbarState copyWith({List<SbarTransfer>? transfers, bool? loading}) =>
      SbarState(
        transfers: transfers ?? this.transfers,
        loading: loading ?? this.loading,
      );
}

class SbarNotifier extends StateNotifier<SbarState> {
  SbarNotifier(this._api, this._ref) : super(const SbarState());

  final SbarApi _api;
  final Ref _ref;

  /// The backend has no plain "list all" endpoint (only per-patient and
  /// per-id lookups), so the aggregate feed is built by fetching every
  /// patient and merging their individual timelines — mirrors
  /// SbarStore.loadTransfers() in the Angular app.
  Future<void> load() async {
    state = state.copyWith(loading: true);
    var patients = _ref.read(patientNotifierProvider).patients;
    if (patients.isEmpty) {
      await _ref.read(patientNotifierProvider.notifier).load();
      patients = _ref.read(patientNotifierProvider).patients;
    }
    final results = await Future.wait(
      patients.map((p) => _api.getByPatientId(p.id)),
    );
    final transfers = results.expand((t) => t).toList()
      ..sort((a, b) {
        final aDate = a.transferredAt;
        final bDate = b.transferredAt;
        if (aDate == null || bDate == null) return 0;
        return bDate.compareTo(aDate);
      });
    state = state.copyWith(transfers: transfers, loading: false);
  }

  Future<List<SbarTransfer>> loadForPatient(String patientId) =>
      _api.getByPatientId(patientId);

  Future<SbarTransfer> register(RegisterSbarCommand command) async {
    final created = await _api.register(command);
    state = state.copyWith(transfers: [created, ...state.transfers]);
    registerAudit(
      _ref,
      entityType: 'SBAR_HANDOVER',
      entityId: created.id,
      actionType: 'HANDOVER',
      patientId: created.patientId,
    );
    return created;
  }

  Future<void> acknowledge(String id) async {
    final updated = await _api.acknowledge(id);
    state = state.copyWith(
      transfers: [
        for (final t in state.transfers)
          if (t.id == updated.id) updated else t,
      ],
    );
    registerAudit(
      _ref,
      entityType: 'SBAR_HANDOVER',
      entityId: updated.id,
      actionType: 'HANDOVER',
      patientId: updated.patientId,
    );
  }
}

final sbarNotifierProvider = StateNotifierProvider<SbarNotifier, SbarState>(
  (ref) => SbarNotifier(ref.watch(sbarApiProvider), ref),
);
