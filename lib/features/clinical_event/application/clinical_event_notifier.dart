import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../audit/infrastructure/audit_api.dart';
import '../../iam/application/auth_notifier.dart';
import '../../iam/domain/user.dart';
import '../../notification/application/alert_notifier.dart';
import '../../notification/domain/alert.dart';
import '../../patient/application/patient_detail.dart';
import '../../patient/domain/patient.dart';
import '../../patient/infrastructure/patient_api.dart';
import '../domain/clinical_event.dart';
import '../domain/clinical_event_rules.dart';
import '../infrastructure/clinical_event_api.dart';
import 'clinical_event_effects.dart';

String describeClinicalEventError(Object error) =>
    error is FormatException ? error.message : describeDioError(error);

class ClinicalEventState {
  const ClinicalEventState({
    this.events = const [],
    this.loading = false,
    this.saving = false,
    this.error,
    this.warning,
  });
  final List<ClinicalEvent> events;
  final bool loading, saving;
  final String? error, warning;

  ClinicalEventState copyWith({
    List<ClinicalEvent>? events,
    bool? loading,
    bool? saving,
    String? error,
    String? warning,
    bool clearError = false,
    bool clearWarning = false,
  }) => ClinicalEventState(
    events: events ?? this.events,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    error: clearError ? null : error ?? this.error,
    warning: clearWarning ? null : warning ?? this.warning,
  );
}

class ClinicalEventNotifier extends StateNotifier<ClinicalEventState> {
  ClinicalEventNotifier(
    this._api,
    this._user,
    this._patient,
    this._effects, {
    this.onSaved,
  }) : super(const ClinicalEventState());

  final ClinicalEventApi _api;
  final User? Function() _user;
  final Future<Patient> Function(String) _patient;
  final ClinicalEventEffects _effects;
  final void Function(ClinicalEvent)? onSaved;
  int _loadId = 0, _revision = 0;

  static List<ClinicalEvent> _sorted(Iterable<ClinicalEvent> events) =>
      events.toList()..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  Future<void> load() async {
    if (state.saving) return;
    final request = ++_loadId;
    final revision = _revision;
    state = state.copyWith(loading: true, clearError: true);
    try {
      if (!ClinicalEventRules.canRegister(_user()?.roles ?? const [])) {
        throw const FormatException(
          'No tienes permiso para consultar eventos clínicos.',
        );
      }
      final events = await _api.getAll();
      if (mounted && request == _loadId && revision == _revision) {
        state = state.copyWith(events: _sorted(events));
      }
    } catch (e) {
      if (mounted && request == _loadId && revision == _revision) {
        state = state.copyWith(error: describeClinicalEventError(e));
      }
    } finally {
      if (mounted && request == _loadId) state = state.copyWith(loading: false);
    }
  }

  Future<List<ClinicalEvent>> loadForPatient(String patientId) async {
    if (!ClinicalEventRules.canRegister(_user()?.roles ?? const [])) {
      throw const FormatException(
        'No tienes permiso para consultar eventos clínicos.',
      );
    }
    final error = ClinicalEventRules.patient(patientId);
    if (error != null) throw FormatException(error);
    return _sorted(
      await _api.getByPatientId(int.parse(patientId.trim()).toString()),
    );
  }

  void clearWarning() => state = state.copyWith(clearWarning: true);

  Future<ClinicalEvent> register(RegisterClinicalEventCommand command) async {
    final actor = _user();
    if (actor == null || !ClinicalEventRules.canRegister(actor.roles)) {
      throw const FormatException(
        'No tienes permiso para registrar eventos clínicos.',
      );
    }
    if (state.saving) {
      throw const FormatException('Espera a que termine el registro en curso.');
    }
    final validated = ClinicalEventRules.validate(command);
    _revision++;
    state = state.copyWith(saving: true, clearWarning: true);
    try {
      final patient = await _patient(validated.patientId);
      if (patient.id != validated.patientId) {
        throw const FormatException(
          'El paciente seleccionado no está disponible.',
        );
      }
      if (!mounted) {
        throw const FormatException(
          'La operación se canceló antes de guardar.',
        );
      }
      final current = _user();
      if (current == null ||
          current.id != actor.id ||
          current.username != actor.username ||
          !ClinicalEventRules.canRegister(current.roles)) {
        throw const FormatException(
          'La sesión cambió. Inicia el registro de nuevo.',
        );
      }
      final created = await _api.register(validated);
      if (mounted) {
        state = state.copyWith(
          events: _sorted([
            created,
            ...state.events.where((e) => e.id != created.id),
          ]),
        );
        final warning = await _effects.run(created, actor);
        if (mounted) {
          state = state.copyWith(
            warning: warning,
            clearWarning: warning == null,
          );
          // Una falla local posterior no convierte el evento confirmado en fallo.
          try {
            onSaved?.call(created);
          } catch (_) {}
        }
      }
      return created;
    } finally {
      if (mounted) state = state.copyWith(saving: false);
    }
  }
}

final clinicalEventUserProvider = Provider<User?>(
  (ref) => ref.watch(authNotifierProvider.select((s) => s.user)),
);
final clinicalEventCanRegisterProvider = Provider<bool>(
  (ref) => ClinicalEventRules.canRegister(
    ref.watch(clinicalEventUserProvider)?.roles ?? const [],
  ),
);
final clinicalEventEffectsProvider = Provider<ClinicalEventEffects>((ref) {
  final auditApi = ref.watch(auditApiProvider);
  final alerts = ref.watch(alertNotifierProvider.notifier);
  return ClinicalEventEffects(
    audit: (event, actor) async {
      await auditApi.create(
        entityType: 'CLINICAL_EVENT',
        entityId: event.id,
        actionType: 'CREATE',
        performedBy: actor.username,
        patientId: event.patientId,
      );
    },
    createAlert: (event, _) async {
      final receipt = await alerts.create(
        patientId: event.patientId,
        type: AlertType.other,
        severity: event.isCritical
            ? AlertSeverity.critical
            : AlertSeverity.high,
        description: ClinicalEventRules.alertDescription(event),
      );
      if (receipt.readError != null ||
          ref.read(alertNotifierProvider).warning != null) {
        throw const FormatException(
          'Revisa el aviso en Alertas; no repitas el evento.',
        );
      }
    },
  );
});
final clinicalEventNotifierProvider =
    StateNotifierProvider<ClinicalEventNotifier, ClinicalEventState>(
      (ref) => ClinicalEventNotifier(
        ref.watch(clinicalEventApiProvider),
        () => ref.read(clinicalEventUserProvider),
        ref.watch(patientApiProvider).getById,
        ref.watch(clinicalEventEffectsProvider),
        onSaved: (event) =>
            ref.invalidate(patientHistoryProvider(event.patientId)),
      ),
    );
