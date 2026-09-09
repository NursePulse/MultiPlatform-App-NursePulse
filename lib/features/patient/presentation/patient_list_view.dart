import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(patientNotifierProvider.notifier).load());
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
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(patientNotifierProvider.notifier).load(),
              child: AsyncValueView<PatientState>(
                loading: state.loading,
                error: state.error,
                data: state,
                isEmpty: (s) => s.patients.isEmpty,
                onRetry: () =>
                    ref.read(patientNotifierProvider.notifier).load(),
                builder: (context, s) => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: s.patients.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final patient = s.patients[index];
                    return Card(
                      child: ListTile(
                        onTap: () =>
                            context.go('/patients/${patient.id}/monitoring'),
                        leading: CircleAvatar(
                          child: Text(patient.initials),
                        ),
                        title: Text(patient.fullName),
                        subtitle: Text(
                          '${patient.diagnosis} · Hab. ${patient.roomNumber}-${patient.bedNumber} · ${patient.age} años',
                        ),
                        trailing: StatusChip(
                          label: patient.statusLabel,
                          palette: _statusPalette(patient.status),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
