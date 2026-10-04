import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../patient/application/patient_detail.dart';
import '../../../core/network/api_exception.dart';
import '../../dashboard/application/dashboard_notifier.dart';
import '../../audit/infrastructure/audit_api.dart';
import '../../iam/application/auth_notifier.dart';
import '../../iam/domain/user.dart';
import '../../notification/application/alert_notifier.dart';
import '../../notification/domain/alert.dart';
import '../../patient/domain/patient.dart';
import '../../patient/infrastructure/patient_api.dart';
import '../domain/vital_sign.dart';
import '../domain/vital_sign_rules.dart';
import '../infrastructure/vital_sign_api.dart';
import 'vital_sign_effects.dart';

String describeVitalSignError(Object error) =>
    error is FormatException ? error.message : describeDioError(error);

class VitalSignState {
  const VitalSignState({
    this.records = const [],
    this.loading = false,
    this.saving = false,
    this.error,
    this.warning,
  });

  final List<VitalSign> records;
  final bool loading;
  final bool saving;
  final String? error;
  final String? warning;

  VitalSignState copyWith({
    List<VitalSign>? records,
    bool? loading,
    bool? saving,
    String? error,
    String? warning,
    bool clearError = false,
    bool clearWarning = false,
  }) => VitalSignState(
    records: records ?? this.records,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    error: clearError ? null : error ?? this.error,
    warning: clearWarning ? null : warning ?? this.warning,
  );
}

class VitalSignNotifier extends StateNotifier<VitalSignState> {
  VitalSignNotifier(
    this._api,
    this._user,
    this._patient,
    this._effects, {
    this.onSaved,
  }) : super(const VitalSignState());

  final VitalSignApi _api;
  final User? Function() _user;
  final Future<Patient> Function(String) _patient;
  final VitalSignEffects _effects;
  final void Function(VitalSign)? onSaved;

  int _loadId = 0, _revision = 0;

  static List<VitalSign> _sorted(Iterable<VitalSign> signs) =>
      signs.toList()..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

  Future<void> load() async {
    if (state.saving) return;

    final request = ++_loadId;
    final revision = _revision;
    state = state.copyWith(loading: true, clearError: true);

    try {
      final signs = await _api.getAll();

      if (mounted && request == _loadId && revision == _revision) {
        state = state.copyWith(records: _sorted(signs));
      }
    } catch (e) {
      if (mounted && request == _loadId && revision == _revision) {
        state = state.copyWith(error: describeVitalSignError(e));
      }
    } finally {
      if (mounted && request == _loadId) {
        state = state.copyWith(loading: false);
      }
    }
  }

  Future<List<VitalSign>> loadForPatient(String id) => _api.getByPatientId(id);

  void clearWarning() => state = state.copyWith(clearWarning: true);

  Future<VitalSign> record(RecordVitalSignCommand command) async {
    final actor = _user();

    if (actor == null || !VitalSignRules.canRecord(actor.roles)) {
      throw const FormatException(
        'No tienes permiso para registrar signos vitales.',
      );
    }

    if (state.saving) {
      throw const FormatException('Espera a que termine el registro en curso.');
    }

    final validated = VitalSignRules.validate(command, nurseId: actor.id);

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
          !VitalSignRules.canRecord(current.roles)) {
        throw const FormatException(
          'La sesión cambió. Inicia el registro de nuevo.',
        );
      }

      final sign = await _api.record(validated);

      if (mounted) {
        state = state.copyWith(
          records: _sorted([
            sign,
            ...state.records.where((s) => s.id != sign.id),
          ]),
        );

        final warning = await _effects.run(sign, actor);

        if (mounted) {
          state = state.copyWith(
            warning: warning,
            clearWarning: warning == null,
          );

          try {
            onSaved?.call(sign);
          } catch (_) {}
        }
      }

      return sign;
    } finally {
      if (mounted) state = state.copyWith(saving: false);
    }
  }
}

final vitalSignUserProvider = Provider<User?>(
  (ref) => ref.watch(authNotifierProvider.select((state) => state.user)),
);

final vitalSignCanRecordProvider = Provider<bool>(
  (ref) => VitalSignRules.canRecord(
    ref.watch(vitalSignUserProvider)?.roles ?? const [],
  ),
);

final vitalSignEffectsProvider = Provider<VitalSignEffects>((ref) {
  final auditApi = ref.watch(auditApiProvider);
  final alerts = ref.watch(alertNotifierProvider.notifier);

  return VitalSignEffects(
    audit: (sign, actor) async {
      await auditApi.create(
        entityType: 'VITAL_SIGNS',
        entityId: sign.id,
        actionType: 'VITAL_SIGNS_RECORDED',
        performedBy: actor.username,
        patientId: sign.patientId,
      );
    },
    createAlert: (sign, _) async {
      final receipt = await alerts.create(
        patientId: sign.patientId,
        type: AlertType.respiratory,
        severity: sign.isCritical ? AlertSeverity.critical : AlertSeverity.high,
        description: VitalSignRules.alertDescription(sign),
      );
      if (receipt.readError != null ||
          ref.read(alertNotifierProvider).warning != null) {
        throw const FormatException(
          'Revisa el aviso en Alertas; no repitas los signos.',
        );
      }
    },
  );
});

final vitalSignNotifierProvider =
    StateNotifierProvider<VitalSignNotifier, VitalSignState>(
      (ref) => VitalSignNotifier(
        ref.watch(vitalSignApiProvider),
        () => ref.read(vitalSignUserProvider),
        ref.watch(patientApiProvider).getById,
        ref.watch(vitalSignEffectsProvider),
        onSaved: (sign) {
          ref.invalidate(patientHistoryProvider(sign.patientId));
          ref.invalidate(dashboardNotifierProvider);
        },
      ),
    );
