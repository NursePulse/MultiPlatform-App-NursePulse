import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_title.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../patient/application/patient_notifier.dart';
import '../../patient/domain/patient.dart';
import '../application/clinical_event_notifier.dart';
import '../domain/clinical_event.dart';
import 'clinical_event_form_dialog.dart';

ChipPalette _severityPalette(String severity) => switch (severity) {
  ClinicalEventSeverity.low => ClinicalColors.riskLow,
  ClinicalEventSeverity.moderate => ClinicalColors.riskMedium,
  ClinicalEventSeverity.high => ClinicalColors.riskHigh,
  _ => ClinicalColors.riskCritical,
};
final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

class ClinicalEventListView extends ConsumerStatefulWidget {
  const ClinicalEventListView({super.key});

  @override
  ConsumerState<ClinicalEventListView> createState() =>
      _ClinicalEventListViewState();
}

class _ClinicalEventListViewState extends ConsumerState<ClinicalEventListView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(clinicalEventNotifierProvider.notifier).load();
      if (ref.read(clinicalEventCanRegisterProvider)) {
        ref.read(patientNotifierProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clinicalEventNotifierProvider);
    final patients = ref.watch(patientNotifierProvider).patients;
    final allowed = ref.watch(clinicalEventCanRegisterProvider);
    return Scaffold(
      floatingActionButton: allowed
          ? FloatingActionButton.extended(
              onPressed: state.saving
                  ? null
                  : () => showClinicalEventForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Registrar evento'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            const PageTitle('Eventos clínicos'),
            if (state.loading || state.saving) const LinearProgressIndicator(),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: Text(state.error!)),
                    TextButton(
                      onPressed: state.loading || state.saving
                          ? null
                          : () => ref
                                .read(clinicalEventNotifierProvider.notifier)
                                .load(),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            if (state.warning != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: Text(state.warning!)),
                    IconButton(
                      tooltip: 'Ocultar aviso',
                      icon: const Icon(Icons.close),
                      onPressed: () => ref
                          .read(clinicalEventNotifierProvider.notifier)
                          .clearWarning(),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(clinicalEventNotifierProvider.notifier).load(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    if (state.events.isEmpty &&
                        !state.loading &&
                        state.error == null)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No hay eventos clínicos registrados.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    for (final event in state.events)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            title: Text(event.title),
                            subtitle: Text(
                              '${_patientName(patients, event.patientId)} · '
                              '${ClinicalEventType.labelFor(event.eventType)} · '
                              '${_dateFormat.format(event.occurredAt.toLocal())}\n'
                              '${event.description}\nResponsable: ${event.registeredBy}',
                            ),
                            trailing: StatusChip(
                              label: ClinicalEventSeverity.labelFor(
                                event.severity,
                              ),
                              palette: _severityPalette(event.severity),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _patientName(Iterable<Patient> patients, String id) {
    for (final patient in patients) {
      if (patient.id == id) return patient.fullName;
    }
    return 'Paciente #$id';
  }
}
