import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../dashboard/application/dashboard_notifier.dart';
import '../../audit/infrastructure/audit_api.dart';
import '../../iam/application/auth_notifier.dart';
import '../../iam/domain/user.dart';
import '../../patient/application/patient_detail.dart';
import '../../patient/domain/patient.dart';
import '../../patient/infrastructure/patient_api.dart';
import '../domain/alert.dart';
import '../domain/alert_rules.dart';
import '../infrastructure/alert_api.dart';

String describeAlertError(Object error) =>
    error is FormatException ? error.message : describeDioError(error);

class AlertState {
  const AlertState({
    this.alerts = const [],
    this.loading = false,
    this.saving = false,
    this.savingId,
    this.error,
    this.warning,
    this.confirmedActions = const {},
  });
  final List<Alert> alerts;
  final bool loading, saving;
  final String? savingId, error, warning;
  final Set<String> confirmedActions;

  AlertState copyWith({
    List<Alert>? alerts,
    bool? loading,
    bool? saving,
    String? savingId,
    String? error,
    String? warning,
    Set<String>? confirmedActions,
    bool clearSavingId = false,
    bool clearError = false,
    bool clearWarning = false,
  }) => AlertState(
    alerts: alerts ?? this.alerts,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    savingId: clearSavingId ? null : savingId ?? this.savingId,
    error: clearError ? null : error ?? this.error,
    warning: clearWarning ? null : warning ?? this.warning,
    confirmedActions: confirmedActions ?? this.confirmedActions,
  );
}

typedef AlertAudit = Future<void> Function(
  String id,
  String patientId,
  String action,
  User actor,
);

class AlertNotifier extends StateNotifier<AlertState> {
  AlertNotifier(
    this._api,
    this._user,
    this._patient, {
    required this.audit,
    this.onChanged,
  }) : super(const AlertState());
  final AlertApi _api;
  final User? Function() _user;
  final Future<Patient> Function(String) _patient;
  final AlertAudit audit;
  final void Function(String id, String patientId)? onChanged;
  int _request = 0, _revision = 0;

  static List<Alert> _sorted(Iterable<Alert> alerts) =>
      alerts.toList()..sort((a, b) {
        if (a.triggeredAt == null) return b.triggeredAt == null ? 0 : 1;
        if (b.triggeredAt == null) return -1;
        return b.triggeredAt!.compareTo(a.triggeredAt!);
      });

  User _actor({bool closing = false}) {
    final actor = _user();
    if (actor == null ||
        !AlertRules.canManage(actor.roles) ||
        (closing && !AlertRules.canClose(actor.roles))) {
      throw FormatException(
        closing
            ? 'Solo Doctor o Admin pueden cerrar alertas.'
            : 'No tienes permiso para gestionar alertas.',
      );
    }
    AlertRules.actor(actor.username);
    return actor;
  }

  void _checkSession(User actor, {bool closing = false}) {
    if (!mounted) {
      throw const FormatException(
        'La sesión cambió. Inicia la operación de nuevo.',
      );
    }
    final current = _actor(closing: closing);
    if (actor.id != current.id || actor.username != current.username) {
      throw const FormatException(
        'La sesión cambió. Inicia la operación de nuevo.',
      );
    }
  }

  void _begin({String? id}) {
    if (state.saving) {
      throw const FormatException(
        'Espera a que termine la operación en curso.',
      );
    }
    _revision++;
    state = state.copyWith(
      saving: true,
      savingId: id,
      clearSavingId: id == null,
      clearWarning: true,
      clearError: true,
    );
  }

  void _replace(Alert alert) {
    if (mounted) {
      state = state.copyWith(
        alerts: _sorted([
          alert,
          ...state.alerts.where((a) => a.id != alert.id),
        ]),
      );
    }
  }

  Future<void> load() async {
    if (state.saving) return;
    final request = ++_request, revision = _revision;
    state = state.copyWith(loading: true, clearError: true);
    try {
      _actor();
      final alerts = await _api.getAll();
      if (mounted && request == _request && revision == _revision) {
        state = state.copyWith(alerts: _sorted(alerts));
      }
    } catch (e) {
      if (mounted && request == _request && revision == _revision) {
        state = state.copyWith(error: describeAlertError(e));
      }
    } finally {
      if (mounted && request == _request) {
        state = state.copyWith(loading: false);
      }
    }
  }

  Future<List<Alert>> loadForPatient(String id) async {
    _actor();
    final error = AlertRules.id(id, 'un paciente');
    if (error != null) throw FormatException(error);
    return _sorted(await _api.getByPatientId(int.parse(id.trim()).toString()));
  }

  void clearWarning() => state = state.copyWith(clearWarning: true);

  Future<void> _confirmed(
    AlertWriteReceipt receipt,
    String patientId,
    String action,
    User actor, {
    String? key,
  }) async {
    if (!mounted) return;
    if (receipt.alert != null) _replace(receipt.alert!);
    if (key != null) {
      state = state.copyWith(
        confirmedActions: {...state.confirmedActions, key},
      );
    }
    final warnings = <String>[];
    if (receipt.readError != null) {
      warnings.add(
        'El cambio de alerta fue confirmado, pero no se pudo leer el detalle. Recarga; no repitas la operación.',
      );
    }
    if (receipt.id != null) {
      try {
        await audit(receipt.id!, patientId, action, actor);
      } catch (_) {
        warnings.add(
          'La alerta se guardó, pero no se pudo confirmar su auditoría.',
        );
      }
      if (mounted) {
        try {
          onChanged?.call(receipt.id!, patientId);
        } catch (_) {}
      }
    }
    if (mounted) {
      state = state.copyWith(
        warning: warnings.isEmpty ? null : warnings.join(' '),
        clearWarning: warnings.isEmpty,
      );
    }
  }

  Future<AlertWriteReceipt> create({
    required String patientId,
    required String type,
    required AlertSeverity severity,
    required String description,
  }) async {
    final actor = _actor();
    AlertRules.validateCreate(patientId, type, description);
    final id = int.parse(patientId.trim()).toString();
    _begin();
    try {
      final patient = await _patient(id);
      if (patient.id != id) {
        throw const FormatException(
          'El paciente seleccionado no está disponible.',
        );
      }
      _checkSession(actor);
      final receipt = await _api.create(
        patientId: id,
        type: type,
        severity: severity,
        description: description.trim(),
        // Paridad web: el origen de la creación es el equipo clínico.
        triggeredBy: alertDefaultActor,
      );
      await _confirmed(receipt, id, 'ALERT_TRIGGERED', actor);
      return receipt;
    } finally {
      if (mounted) state = state.copyWith(saving: false, clearSavingId: true);
    }
  }

  Future<void> attend(String id) => _transition(id, closing: false);
  Future<void> close(String id, {String resolutionNotes = alertClosingNotes}) =>
      _transition(id, closing: true, notes: resolutionNotes);

  Future<void> _transition(
    String rawId, {
    required bool closing,
    String notes = alertClosingNotes,
  }) async {
    final actor = _actor(closing: closing);
    final error = AlertRules.id(rawId, 'una alerta');
    if (error != null) throw FormatException(error);
    final id = int.parse(rawId.trim()).toString();
    final validatedNotes = closing ? AlertRules.notes(notes) : null;
    final key = '$id:${closing ? 'CLOSED' : 'ATTENDED'}';
    if (state.confirmedActions.contains(key)) return;
    _begin(id: id);
    try {
      final latest = await _api.getById(id);
      _replace(latest);
      final expected = closing ? AlertStatus.attended : AlertStatus.open;
      if (latest.status != expected) {
        throw FormatException(
          closing
              ? 'Solo se pueden cerrar alertas atendidas. Estado actual: ${latest.statusLabel}.'
              : 'Solo se pueden atender alertas activas. Estado actual: ${latest.statusLabel}.',
        );
      }
      _checkSession(actor, closing: closing);
      final receipt = closing
          ? await _api.close(
              id,
              actor.username.trim(),
              resolutionNotes: validatedNotes!,
              patientId: latest.patientId,
            )
          : await _api.attend(
              id,
              actor.username.trim(),
              patientId: latest.patientId,
            );
      await _confirmed(
        receipt,
        latest.patientId,
        closing ? 'UPDATE' : 'ALERT_ACKNOWLEDGED',
        actor,
        key: key,
      );
    } finally {
      if (mounted) state = state.copyWith(saving: false, clearSavingId: true);
    }
  }
}

final alertUserProvider = Provider<User?>(
  (ref) => ref.watch(authNotifierProvider.select((s) => s.user)),
);
final alertCanManageProvider = Provider<bool>(
  (ref) =>
      AlertRules.canManage(ref.watch(alertUserProvider)?.roles ?? const []),
);
final alertCanCloseProvider = Provider<bool>(
  (ref) => AlertRules.canClose(ref.watch(alertUserProvider)?.roles ?? const []),
);
final alertDetailProvider = FutureProvider.autoDispose.family<Alert, String>((
  ref,
  id,
) {
  ref.watch(alertUserProvider);
  if (!ref.watch(alertCanManageProvider)) {
    throw const FormatException('No tienes permiso para consultar alertas.');
  }
  final error = AlertRules.id(id, 'una alerta');
  if (error != null) throw FormatException(error);
  return ref.watch(alertApiProvider).getById(int.parse(id.trim()).toString());
});
final alertNotifierProvider = StateNotifierProvider<AlertNotifier, AlertState>((
  ref,
) {
  ref.watch(alertUserProvider);
  final auditApi = ref.watch(auditApiProvider);
  return AlertNotifier(
    ref.watch(alertApiProvider),
    () => ref.read(alertUserProvider),
    ref.watch(patientApiProvider).getById,
    audit: (id, patientId, action, actor) async {
      await auditApi.create(
        entityType: 'ALERT',
        entityId: id,
        actionType: action,
        performedBy: actor.username,
        patientId: patientId,
      );
    },
    onChanged: (id, patientId) {
      ref.invalidate(alertDetailProvider(id));
      ref.invalidate(patientHistoryProvider(patientId));
      ref.invalidate(dashboardNotifierProvider);
    },
  );
});
