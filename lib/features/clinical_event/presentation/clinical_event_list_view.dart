import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/page_title.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../patient/application/patient_notifier.dart';
import '../../patient/domain/patient.dart';
import '../application/clinical_event_notifier.dart';
import '../domain/clinical_event.dart';

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
      ref.read(clinicalEventNotifierProvider.notifier).load();
      ref.read(patientNotifierProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clinicalEventNotifierProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRegisterDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Registrar evento'),
      ),
      body: Column(
        children: [
          const PageTitle('Eventos clínicos'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(clinicalEventNotifierProvider.notifier).load(),
              child: AsyncValueView<ClinicalEventState>(
                loading: state.loading,
                error: state.error,
                data: state,
                isEmpty: (s) => s.events.isEmpty,
                onRetry: () =>
                    ref.read(clinicalEventNotifierProvider.notifier).load(),
                builder: (context, s) => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: s.events.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final event = s.events[index];
                    final patient = ref
                        .read(patientNotifierProvider.notifier)
                        .byId(event.patientId);
                    return Card(
                      child: ListTile(
                        title: Text(event.title),
                        subtitle: Text(
                          '${patient?.fullName ?? 'Paciente #${event.patientId}'} · '
                          '${ClinicalEventType.labelFor(event.eventType)} · '
                          '${_dateFormat.format(event.occurredAt)}\n'
                          '${event.description}',
                        ),
                        isThreeLine: true,
                        trailing: StatusChip(
                          label: ClinicalEventSeverity.labelFor(
                            event.severity,
                          ),
                          palette: _severityPalette(event.severity),
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

  Future<void> _showRegisterDialog(BuildContext context) async {
    final patients = ref.read(patientNotifierProvider).patients;
    if (patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registra un paciente primero.')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => _RegisterEventDialog(patients: patients),
    );
  }
}

class _RegisterEventDialog extends ConsumerStatefulWidget {
  const _RegisterEventDialog({required this.patients});

  final List<Patient> patients;

  @override
  ConsumerState<_RegisterEventDialog> createState() =>
      _RegisterEventDialogState();
}

class _RegisterEventDialogState extends ConsumerState<_RegisterEventDialog> {
  final _formKey = GlobalKey<FormState>();
  late Patient _patient = widget.patients.first;
  String _eventType = ClinicalEventType.values.first;
  String _severity = ClinicalEventSeverity.values.first;
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(clinicalEventNotifierProvider.notifier)
          .register(
            RegisterClinicalEventCommand(
              patientId: _patient.id,
              eventType: _eventType,
              severity: _severity,
              title: _title.text.trim(),
              description: _description.text.trim(),
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = describeDioError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar evento clínico'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Patient>(
                initialValue: _patient,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Paciente'),
                items: [
                  for (final patient in widget.patients)
                    DropdownMenuItem(
                      value: patient,
                      child: Text(patient.fullName),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _patient = value ?? _patient),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _eventType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo de evento'),
                items: [
                  for (final type in ClinicalEventType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(ClinicalEventType.labelFor(type)),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _eventType = value ?? _eventType),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _severity,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Severidad'),
                items: [
                  for (final severity in ClinicalEventSeverity.values)
                    DropdownMenuItem(
                      value: severity,
                      child: Text(ClinicalEventSeverity.labelFor(severity)),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _severity = value ?? _severity),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Requerido'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 3,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Requerido'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
