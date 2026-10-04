import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../dashboard/application/dashboard_notifier.dart';
import '../../audit/application/audit_register.dart';
import '../../iam/application/auth_notifier.dart';
import '../../iam/domain/user.dart';
import '../../iam/infrastructure/iam_api.dart';
import '../domain/patient.dart';
import '../domain/patient_rules.dart';
import '../infrastructure/patient_api.dart';
import 'patient_detail.dart';

String describePatientError(Object error) {
  if (error is FormatException) return error.message;

  if (error is DioException && error.response?.statusCode == 409) {
    return 'Ya existe un paciente con ese documento. Actualiza el listado.';
  }

  return describeDioError(error);
}

class PatientState {
  const PatientState({
    this.patients = const [],
    this.loading = false,
    this.saving = false,
    this.error,
  });

  final List<Patient> patients;
  final bool loading;
  final bool saving;
  final String? error;

  PatientState copyWith({
    List<Patient>? patients,
    bool? loading,
    bool? saving,
    String? error,
    bool clearError = false,
  }) => PatientState(
    patients: patients ?? this.patients,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    error: clearError ? null : error ?? this.error,
  );
}

class PatientNotifier extends StateNotifier<PatientState> {
  PatientNotifier(this._api, this._roles, {this.audit, this.onChanged})
    : super(const PatientState());

  final PatientApi _api;
  final List<String> Function() _roles;
  final Future<void> Function(Patient, String)? audit;
  final void Function(String id)? onChanged;

  int _loadId = 0;
  int _revision = 0;

  Future<void> load() async {
    if (state.saving) return;

    final request = ++_loadId;
    final revision = _revision;

    state = state.copyWith(loading: true, clearError: true);

    try {
      final patients = await _api.getAll();

      if (mounted && request == _loadId && revision == _revision) {
        state = state.copyWith(patients: List.unmodifiable(patients));
      }
    } catch (e) {
      if (mounted && request == _loadId && revision == _revision) {
        state = state.copyWith(error: describePatientError(e));
      }
    } finally {
      if (mounted && request == _loadId) {
        state = state.copyWith(loading: false);
      }
    }
  }

  void _begin(bool allowed) {
    if (!allowed) {
      throw const FormatException(
        'No tienes permisos para realizar esta acción.',
      );
    }

    if (state.saving) {
      throw const FormatException(
        'Espera a que termine la operación en curso.',
      );
    }

    _revision++;
    state = state.copyWith(saving: true);
  }

  Future<Patient> _save(
    RegisterPatientCommand command, {
    String? id,
    bool validate = true,
  }) async {
    final permissions = PatientPermissions(_roles());
    _begin(id == null ? permissions.create : permissions.update);

    try {
      final validated = validate ? PatientRules.validate(command) : command;

      if (PatientRules.duplicate(
        state.patients,
        validated.documentNumber,
        excludingId: id,
      )) {
        throw const FormatException('Ya existe un paciente con ese documento.');
      }

      final patient = id == null
          ? await _api.create(validated)
          : await _api.update(id, validated);

      if (mounted) {
        final exists = state.patients.any((p) => p.id == patient.id);

        state = state.copyWith(
          patients: [
            for (final p in state.patients)
              if (p.id == patient.id) patient else p,
            if (!exists) patient,
          ],
        );

        // La auditoría no revierte una escritura confirmada por el servidor.
        try {
          await audit?.call(patient, id == null ? 'CREATE' : 'UPDATE');
        } catch (_) {}
        try {
          onChanged?.call(patient.id);
        } catch (_) {}
      }

      return patient;
    } finally {
      if (mounted) state = state.copyWith(saving: false);
    }
  }

  Future<Patient> create(RegisterPatientCommand c) => _save(c);

  Future<Patient> update(String id, RegisterPatientCommand c) =>
      _save(c, id: id);

  Future<void> discharge(String id) async {
    final p = byId(id);

    if (p == null) {
      throw const FormatException(
        'El paciente ya no está disponible. Actualiza el listado.',
      );
    }

    if (p.status == PatientStatus.discharged) return;

    await _save(
      RegisterPatientCommand(
        firstName: p.firstName,
        lastName: p.lastName,
        documentNumber: p.documentNumber,
        birthDate: p.birthDate,
        gender: p.gender,
        diagnosis: p.diagnosis,
        roomNumber: p.roomNumber,
        bedNumber: p.bedNumber,
        attendingPhysician: p.attendingPhysician,
        admissionDate: p.admissionDate,
        status: PatientStatus.discharged,
      ),
      id: id,
      validate: false,
    );
  }

  Future<void> delete(String id) async {
    _begin(PatientPermissions(_roles()).delete);

    try {
      await _api.delete(id);

      if (mounted) {
        state = state.copyWith(
          patients: state.patients.where((p) => p.id != id).toList(),
        );
        try {
          onChanged?.call(id);
        } catch (_) {}
      }
    } finally {
      if (mounted) state = state.copyWith(saving: false);
    }
  }

  Patient? byId(String id) {
    for (final p in state.patients) {
      if (p.id == id) return p;
    }
    return null;
  }
}

final patientPermissionsProvider = Provider(
  (ref) => PatientPermissions(
    ref.watch(
      authNotifierProvider.select((s) => s.user?.roles ?? const <String>[]),
    ),
  ),
);

final patientDoctorsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final users = await ref.watch(usersApiProvider).getAll();

  final names =
      users
          .where((u) => u.roles.contains(kRoleDoctor))
          .map((u) => u.displayName)
          .toSet()
          .toList()
        ..sort();

  return names;
});

final patientNotifierProvider =
    StateNotifierProvider<PatientNotifier, PatientState>(
      (ref) => PatientNotifier(
        ref.watch(patientApiProvider),
        () => ref.read(patientPermissionsProvider).roles,
        audit: (p, action) => registerAudit(
          ref,
          entityType: 'PATIENT',
          entityId: p.id,
          actionType: action,
          patientId: p.id,
        ),
        onChanged: (id) {
          ref.invalidate(patientDetailProvider(id));
          ref.invalidate(patientHistoryProvider(id));
          ref.invalidate(dashboardNotifierProvider);
        },
      ),
    );
