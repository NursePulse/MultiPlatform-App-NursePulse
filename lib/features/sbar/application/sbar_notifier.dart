import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../dashboard/application/dashboard_notifier.dart';
import '../../audit/infrastructure/audit_api.dart';
import '../../iam/application/auth_notifier.dart';
import '../../iam/domain/user.dart';
import '../../iam/infrastructure/iam_api.dart';
import '../../patient/domain/patient.dart';
import '../../patient/infrastructure/patient_api.dart';
import '../domain/sbar_rules.dart';
import '../domain/sbar_transfer.dart';
import '../infrastructure/sbar_api.dart';

String describeSbarError(Object error) =>
    error is FormatException ? error.message : describeDioError(error);
const sbarAcknowledgementNotes = 'Traspaso SBAR revisado y atendido.';

class SbarState {
  const SbarState({
    this.transfers = const [],
    this.loading = false,
    this.saving = false,
    this.savingId,
    this.error,
    this.warning,
    this.confirmedAcknowledgements = const {},
  });
  final List<SbarTransfer> transfers;
  final bool loading, saving;
  final String? savingId, error, warning;
  final Set<String> confirmedAcknowledgements;

  SbarState copyWith({
    List<SbarTransfer>? transfers,
    bool? loading,
    bool? saving,
    String? savingId,
    String? error,
    String? warning,
    Set<String>? confirmedAcknowledgements,
    bool clearSavingId = false,
    bool clearError = false,
    bool clearWarning = false,
  }) => SbarState(
    transfers: transfers ?? this.transfers,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    savingId: clearSavingId ? null : savingId ?? this.savingId,
    error: clearError ? null : error ?? this.error,
    warning: clearWarning ? null : warning ?? this.warning,
    confirmedAcknowledgements:
        confirmedAcknowledgements ?? this.confirmedAcknowledgements,
  );
}

typedef SbarAudit = Future<void> Function(
  String id,
  String patientId,
  User actor,
);

class SbarNotifier extends StateNotifier<SbarState> {
  SbarNotifier(
    this._api,
    this._user,
    this._patients,
    this._patient,
    this._users, {
    required this.audit,
    this.onChanged,
  }) : super(const SbarState());
  final SbarApi _api;
  final User? Function() _user;
  final Future<List<Patient>> Function() _patients;
  final Future<Patient> Function(String) _patient;
  final Future<List<User>> Function() _users;
  final SbarAudit audit;
  final void Function(String id)? onChanged;
  int _loadId = 0, _revision = 0;

  static List<SbarTransfer> _sorted(Iterable<SbarTransfer> transfers) =>
      transfers.toList()..sort((a, b) {
        if (a.transferredAt == null) return b.transferredAt == null ? 0 : 1;
        if (b.transferredAt == null) return -1;
        return b.transferredAt!.compareTo(a.transferredAt!);
      });

  Future<void> load() async {
    if (state.saving) return;
    final request = ++_loadId, revision = _revision;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final actor = _user();
      if (!SbarRules.canRead(actor?.roles ?? const [])) {
        throw const FormatException(
          'No tienes permiso para consultar traspasos.',
        );
      }
      // El controlador no expone GET /handovers: se agregan consultas por paciente.
      final patients = await _patients();
      if (!mounted) return;
      final current = _user();
      if (current == null ||
          current.id != actor!.id ||
          current.username != actor.username ||
          !SbarRules.canRead(current.roles)) {
        throw const FormatException('La sesión cambió. Recarga los traspasos.');
      }
      final groups = await Future.wait(
        patients.map((p) => _api.getByPatientId(p.id)),
      );
      if (mounted && request == _loadId && revision == _revision) {
        state = state.copyWith(transfers: _sorted(groups.expand((g) => g)));
      }
    } catch (e) {
      if (mounted && request == _loadId && revision == _revision) {
        state = state.copyWith(error: describeSbarError(e));
      }
    } finally {
      if (mounted && request == _loadId) state = state.copyWith(loading: false);
    }
  }

  Future<List<SbarTransfer>> loadForPatient(String id) async {
    if (!SbarRules.canRead(_user()?.roles ?? const [])) {
      throw const FormatException(
        'No tienes permiso para consultar traspasos.',
      );
    }
    final error = SbarRules.id(id, 'un paciente');
    if (error != null) throw FormatException(error);
    return _sorted(await _api.getByPatientId(int.parse(id.trim()).toString()));
  }

  User _begin({String? id, bool clearWarning = true}) {
    final actor = _user();
    if (actor == null || !SbarRules.canManage(actor.roles)) {
      throw const FormatException(
        'No tienes permiso para registrar o recibir traspasos.',
      );
    }
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
      clearWarning: clearWarning,
    );
    return actor;
  }

  void _checkSession(User actor) {
    if (!mounted) {
      throw const FormatException('La operación se canceló antes de guardar.');
    }
    final current = _user();
    if (current == null ||
        current.id != actor.id ||
        current.username != actor.username ||
        !SbarRules.canManage(current.roles)) {
      throw const FormatException(
        'La sesión cambió. Inicia la operación de nuevo.',
      );
    }
  }

  void _replace(SbarTransfer transfer) {
    if (!mounted) return;
    state = state.copyWith(
      transfers: _sorted([
        transfer,
        ...state.transfers.where((t) => t.id != transfer.id),
      ]),
    );
  }

  Future<void> _confirmed(
    SbarWriteReceipt receipt,
    String patientId,
    User actor, {
    bool acknowledgement = false,
  }) async {
    if (!mounted) return;
    if (receipt.transfer != null) _replace(receipt.transfer!);
    if (acknowledgement && receipt.id != null) {
      state = state.copyWith(
        confirmedAcknowledgements: {
          ...state.confirmedAcknowledgements,
          receipt.id!,
        },
      );
    }
    final warnings = <String>[];
    if (receipt.readError != null) {
      warnings.add(
        acknowledgement
            ? 'La recepción fue confirmada, pero no se pudo leer el detalle. Recarga el listado; no repitas la recepción.'
            : 'El traspaso fue confirmado, pero no se pudo leer el detalle. Recarga el listado; no vuelvas a registrarlo.',
      );
    }
    if (receipt.id != null) {
      try {
        await audit(receipt.id!, patientId, actor);
      } catch (_) {
        warnings.add(
          'El cambio se guardó, pero no se pudo confirmar su auditoría.',
        );
      }
      if (mounted) {
        try {
          onChanged?.call(receipt.id!);
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

  Future<SbarWriteReceipt> register(RegisterSbarCommand command) async {
    // Validación antes de consultar catálogos o realizar escrituras.
    final actor = _user();
    if (actor == null || !SbarRules.canManage(actor.roles)) {
      throw const FormatException(
        'No tienes permiso para registrar traspasos.',
      );
    }
    final validated = SbarRules.validate(command, actorId: actor.id);
    _begin();
    try {
      final patient = await _patient(validated.patientId);
      if (patient.id != validated.patientId) {
        throw const FormatException(
          'El paciente seleccionado no está disponible.',
        );
      }
      final users = await _users();
      if (!SbarRules.receivers(
        users,
        actor.id,
      ).any((u) => u.id == validated.targetNurseId)) {
        throw const FormatException(
          'El receptor seleccionado ya no es un usuario Nurse disponible.',
        );
      }
      _checkSession(actor);
      final receipt = await _api.register(validated);
      await _confirmed(receipt, patient.id, actor);
      return receipt;
    } finally {
      if (mounted) state = state.copyWith(saving: false, clearSavingId: true);
    }
  }

  Future<void> acknowledge(String id) async {
    final error = SbarRules.id(id, 'un traspaso');
    if (error != null) throw FormatException(error);
    id = int.parse(id.trim()).toString();
    final actor = _begin(
      id: id,
      clearWarning: !state.confirmedAcknowledgements.contains(id),
    );
    try {
      if (state.confirmedAcknowledgements.contains(id)) return;
      final latest = await _api.getById(id);
      _checkSession(actor);
      if (!latest.canAcknowledge) {
        _replace(latest);
        return;
      }
      final receipt = await _api.acknowledge(
        id,
        additionalNotes: sbarAcknowledgementNotes,
      );
      await _confirmed(receipt, latest.patientId, actor, acknowledgement: true);
    } finally {
      if (mounted) state = state.copyWith(saving: false, clearSavingId: true);
    }
  }

  void clearWarning() => state = state.copyWith(clearWarning: true);
}

final sbarUserProvider = Provider<User?>(
  (ref) => ref.watch(authNotifierProvider.select((s) => s.user)),
);
final sbarCanManageProvider = Provider<bool>(
  (ref) => SbarRules.canManage(ref.watch(sbarUserProvider)?.roles ?? const []),
);
final sbarUsersProvider = FutureProvider.autoDispose<List<User>>((ref) {
  if (!SbarRules.canRead(ref.watch(sbarUserProvider)?.roles ?? const [])) {
    throw const FormatException(
      'No tienes permiso para consultar el directorio.',
    );
  }
  return ref.watch(usersApiProvider).getAll();
});
final sbarReceiversProvider = Provider<AsyncValue<List<User>>>(
  (ref) => ref
      .watch(sbarUsersProvider)
      .whenData(
        (users) => SbarRules.receivers(users, ref.watch(sbarUserProvider)?.id),
      ),
);
final sbarDetailProvider = FutureProvider.autoDispose
    .family<SbarTransfer, String>((ref, id) {
      if (!SbarRules.canRead(ref.watch(sbarUserProvider)?.roles ?? const [])) {
        throw const FormatException(
          'No tienes permiso para consultar traspasos.',
        );
      }
      final error = SbarRules.id(id, 'un traspaso');
      if (error != null) throw FormatException(error);
      return ref
          .watch(sbarApiProvider)
          .getById(int.parse(id.trim()).toString());
    });
final sbarNotifierProvider = StateNotifierProvider<SbarNotifier, SbarState>((
  ref,
) {
  ref.watch(sbarUserProvider);
  final patients = ref.watch(patientApiProvider);
  final users = ref.watch(usersApiProvider);
  final auditApi = ref.watch(auditApiProvider);
  return SbarNotifier(
    ref.watch(sbarApiProvider),
    () => ref.read(sbarUserProvider),
    patients.getAll,
    patients.getById,
    users.getAll,
    audit: (id, patientId, actor) async {
      await auditApi.create(
        entityType: 'SBAR_HANDOVER',
        entityId: id,
        actionType: 'HANDOVER',
        performedBy: actor.username,
        patientId: patientId,
      );
    },
    onChanged: (id) {
      ref.invalidate(sbarDetailProvider(id));
      ref.invalidate(dashboardNotifierProvider);
    },
  );
});
