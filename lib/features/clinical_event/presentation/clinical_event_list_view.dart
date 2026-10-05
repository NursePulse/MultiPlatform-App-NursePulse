import '../../../shared/widgets/list_page_body.dart';
import '../../../core/localization/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_title.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/clinical_card.dart';
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
              icon: Icon(Icons.add),
              label: Text(context.tr('Registrar evento')),
            )
          : null,
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListPageBody(
          header: [
            PageTitle('Eventos clínicos'),
            if (state.loading || state.saving) LinearProgressIndicator(),
            if (state.error != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: Text(context.tr(state.error!))),
                    TextButton(
                      onPressed: state.loading || state.saving
                          ? null
                          : () => ref
                                .read(clinicalEventNotifierProvider.notifier)
                                .load(),
                      child: Text(context.tr('Reintentar')),
                    ),
                  ],
                ),
              ),
            if (state.warning != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: Text(context.tr(state.warning!))),
                    IconButton(
                      tooltip: context.tr('Ocultar aviso'),
                      icon: Icon(Icons.close),
                      onPressed: () => ref
                          .read(clinicalEventNotifierProvider.notifier)
                          .clearWarning(),
                    ),
                  ],
                ),
              ),
          ],
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(clinicalEventNotifierProvider.notifier).load(),
            child: ListView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (state.events.isEmpty &&
                    !state.loading &&
                    state.error == null)
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      context.tr('No hay eventos clínicos registrados.'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final event in state.events)
                  Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: ClinicalCard(
                      children: [
                        Text(
                          event.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SizedBox(height: 4),
                        Text(_patientName(patients, event.patientId)),
                        SizedBox(height: 8),
                        StatusChip(
                          label: ClinicalEventSeverity.labelFor(event.severity),
                          palette: _severityPalette(event.severity),
                        ),
                        SizedBox(height: 8),
                        Text(
                          context.tr(
                            ClinicalEventType.labelFor(event.eventType),
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          _dateFormat.format(event.occurredAt.toLocal()),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        SizedBox(height: 8),
                        Text(event.description),
                        SizedBox(height: 8),
                        Text(
                          context.tr('Responsable: ${event.registeredBy}'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _patientName(Iterable<Patient> patients, String id) {
    for (final patient in patients) {
      if (patient.id == id) return patient.fullName;
    }
    return context.tr('Paciente #$id');
  }
}
