import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/page_title.dart';
import '../../../shared/widgets/status_chip.dart';
import '../application/patient_notifier.dart';
import '../domain/patient.dart';
import 'patient_form_sheet.dart';

ChipPalette _statusPalette(PatientStatus status) => switch (status) {
  PatientStatus.stable => ClinicalColors.patientStable,
  PatientStatus.observation => ClinicalColors.patientObservation,
  PatientStatus.critical => ClinicalColors.patientCritical,
  PatientStatus.discharged => ClinicalColors.patientDischarged,
};

class PatientListView extends ConsumerStatefulWidget {
  const PatientListView({super.key});

  @override
  ConsumerState<PatientListView> createState() => _PatientListViewState();
}

class _PatientListViewState extends ConsumerState<PatientListView> {
  final _queryController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(patientNotifierProvider.notifier).load());
    _queryController.addListener(
      () => setState(() => _query = _queryController.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  /// Mirrors filteredPatients() in patient-list.ts.
  List<Patient> _filter(List<Patient> patients) {
    if (_query.isEmpty) return patients;
    return patients.where((p) {
      final haystack =
          '${p.code} ${p.fullName} ${p.documentNumber} ${p.roomNumber} '
                  '${p.bedNumber} ${p.statusLabel} ${p.diagnosis}'
              .toLowerCase();
      return haystack.contains(_query);
    }).toList();
  }

  Future<void> _discharge(Patient patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text('¿Seguro que deseas dar de alta a este paciente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Dar de alta'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(patientNotifierProvider.notifier).discharge(patient.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeDioError(e))));
      }
    }
  }

  Future<void> _delete(Patient patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text('¿Seguro que deseas eliminar este paciente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(patientNotifierProvider.notifier).delete(patient.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeDioError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(patientNotifierProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showPatientFormSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo paciente'),
      ),
      body: Column(
        children: [
          const PageTitle('Pacientes'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _queryController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por nombre, documento, habitación...',
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(patientNotifierProvider.notifier).load(),
              child: AsyncValueView<PatientState>(
                loading: state.loading,
                error: state.error,
                data: state,
                isEmpty: (s) => _filter(s.patients).isEmpty,
                onRetry: () =>
                    ref.read(patientNotifierProvider.notifier).load(),
                builder: (context, s) {
                  final patients = _filter(s.patients);
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: patients.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final patient = patients[index];
                      return Card(
                        child: ListTile(
                          onTap: () => context.go(
                            '/patients/${patient.id}/monitoring',
                          ),
                          leading: CircleAvatar(child: Text(patient.initials)),
                          title: Text(patient.fullName),
                          subtitle: Text(
                            '${patient.diagnosis} · Hab. ${patient.roomNumber}-${patient.bedNumber} · ${patient.age} años',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StatusChip(
                                label: patient.statusLabel,
                                palette: _statusPalette(patient.status),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (action) => switch (action) {
                                  'edit' => showPatientFormSheet(
                                    context,
                                    editing: patient,
                                  ),
                                  'discharge' => _discharge(patient),
                                  'delete' => _delete(patient),
                                  _ => null,
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Editar'),
                                  ),
                                  if (patient.status !=
                                      PatientStatus.discharged)
                                    const PopupMenuItem(
                                      value: 'discharge',
                                      child: Text('Dar de alta'),
                                    ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Eliminar'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
