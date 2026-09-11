import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../audit/application/audit_register.dart';
import '../domain/patient.dart';
import '../infrastructure/patient_api.dart';

class PatientState {
  const PatientState({
    this.patients = const [],
    this.loading = false,
    this.error,
  });

  final List<Patient> patients;
  final bool loading;
  final String? error;

  PatientState copyWith({
    List<Patient>? patients,
    bool? loading,
    String? error,
  }) => PatientState(
    patients: patients ?? this.patients,
    loading: loading ?? this.loading,
    error: error,
  );
}

class PatientNotifier extends StateNotifier<PatientState> {
  PatientNotifier(this._api, this._ref) : super(const PatientState());

  final PatientApi _api;
  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final patients = await _api.getAll();
      state = state.copyWith(patients: patients, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: describeDioError(e));
    }
  }

  Future<Patient> create(RegisterPatientCommand command) async {
    final patient = await _api.create(command);
    state = state.copyWith(patients: [...state.patients, patient]);
    registerAudit(
      _ref,
      entityType: 'PATIENT',
      entityId: patient.id,
      actionType: 'CREATE',
      patientId: patient.id,
    );
    return patient;
  }

  Future<Patient> update(String id, RegisterPatientCommand command) async {
    final updated = await _api.update(id, command);
    state = state.copyWith(
      patients: [
        for (final p in state.patients)
          if (p.id == id) updated else p,
      ],
    );
    return updated;
  }

  /// Discharging is just an update that flips status to DISCHARGED, keeping
  /// every other field — mirrors dischargePatient() in patient.store.ts.
  Future<void> discharge(String id) async {
    final patient = byId(id);
    if (patient == null) return;
    await update(
      id,
      RegisterPatientCommand(
        firstName: patient.firstName,
        lastName: patient.lastName,
        documentNumber: patient.documentNumber,
        birthDate: patient.birthDate,
        gender: patient.gender,
        diagnosis: patient.diagnosis,
        roomNumber: patient.roomNumber,
        bedNumber: patient.bedNumber,
        attendingPhysician: patient.attendingPhysician,
        status: PatientStatus.discharged,
        admissionDate: patient.admissionDate,
      ),
    );
  }

  Future<void> delete(String id) async {
    await _api.delete(id);
    state = state.copyWith(
      patients: state.patients.where((p) => p.id != id).toList(),
    );
  }

  Patient? byId(String id) {
    for (final patient in state.patients) {
      if (patient.id == id) return patient;
    }
    return null;
  }
}

final patientNotifierProvider =
    StateNotifierProvider<PatientNotifier, PatientState>(
      (ref) => PatientNotifier(ref.watch(patientApiProvider), ref),
    );
