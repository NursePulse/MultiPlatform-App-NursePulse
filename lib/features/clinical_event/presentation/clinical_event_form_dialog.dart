import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../patient/application/patient_notifier.dart';
import '../application/clinical_event_notifier.dart';
import '../domain/clinical_event.dart';
import '../domain/clinical_event_rules.dart';

Future<void> showClinicalEventForm(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => const ClinicalEventFormDialog(),
);

class ClinicalEventFormDialog extends ConsumerStatefulWidget {
  const ClinicalEventFormDialog({super.key});

  @override
  ConsumerState<ClinicalEventFormDialog> createState() =>
      _ClinicalEventFormDialogState();
}

class _ClinicalEventFormDialogState
    extends ConsumerState<ClinicalEventFormDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController(),
      _description = TextEditingController();
  String? _patientId, _error;
  String _type = ClinicalEventType.observation;
  String _severity = ClinicalEventSeverity.low;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy ||
        ref.read(clinicalEventNotifierProvider).saving ||
        !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(clinicalEventNotifierProvider.notifier)
          .register(
            RegisterClinicalEventCommand(
              patientId: _patientId!,
              eventType: _type,
              severity: _severity,
              title: _title.text,
              description: _description.text,
            ),
          );
      if (mounted) {
        final warning = ref.read(clinicalEventNotifierProvider).warning;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(warning ?? 'Evento clínico guardado.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = describeClinicalEventError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(patientNotifierProvider);
    final saving = ref.watch(
      clinicalEventNotifierProvider.select((s) => s.saving),
    );
    final allowed = ref.watch(clinicalEventCanRegisterProvider);
    final blocked = _busy || saving;
    final selected = patients.patients.any((p) => p.id == _patientId);
    return PopScope(
      canPop: !blocked,
      child: AlertDialog(
        title: const Text('Registrar evento clínico'),
        content: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'event-patient-${patients.patients.map((p) => p.id).join(',')}',
                  ),
                  initialValue: selected ? _patientId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Paciente'),
                  items: [
                    for (final p in patients.patients)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          p.fullName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: blocked
                      ? null
                      : (value) => setState(() => _patientId = value),
                  validator: (value) =>
                      value == null ||
                          !patients.patients.any((p) => p.id == value)
                      ? 'Selecciona un paciente disponible.'
                      : ClinicalEventRules.patient(value),
                ),
                if (patients.loading) const LinearProgressIndicator(),
                if (patients.error != null) Text(patients.error!),
                if (patients.error != null || patients.patients.isEmpty)
                  TextButton(
                    onPressed: blocked || patients.loading
                        ? null
                        : () =>
                              ref.read(patientNotifierProvider.notifier).load(),
                    child: const Text('Recargar pacientes'),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const ValueKey('event-type'),
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de evento',
                  ),
                  items: [
                    for (final t in ClinicalEventType.values)
                      DropdownMenuItem(
                        value: t,
                        child: Text(
                          ClinicalEventType.labelFor(t),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: blocked
                      ? null
                      : (value) => setState(() => _type = value ?? _type),
                  validator: ClinicalEventRules.type,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const ValueKey('event-severity'),
                  initialValue: _severity,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Severidad'),
                  items: [
                    for (final s in ClinicalEventSeverity.values)
                      DropdownMenuItem(
                        value: s,
                        child: Text(ClinicalEventSeverity.labelFor(s)),
                      ),
                  ],
                  onChanged: blocked
                      ? null
                      : (value) =>
                            setState(() => _severity = value ?? _severity),
                  validator: ClinicalEventRules.severity,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('event-title'),
                  controller: _title,
                  enabled: !blocked,
                  maxLength: 120,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    helperText: '4–120 caracteres',
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (v) =>
                      ClinicalEventRules.text(v, 'Título', 4, 120),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('event-description'),
                  controller: _description,
                  enabled: !blocked,
                  maxLength: 1000,
                  maxLines: 3,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    helperText: '10–1000 caracteres',
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (v) =>
                      ClinicalEventRules.text(v, 'Descripción', 10, 1000),
                ),
                if (!allowed)
                  const Text(
                    'No tienes permiso para registrar eventos clínicos.',
                  ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('event-cancel'),
            onPressed: blocked ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('event-save'),
            onPressed:
                blocked ||
                    !allowed ||
                    patients.loading ||
                    patients.patients.isEmpty
                ? null
                : _submit,
            child: Text(_busy ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
    );
  }
}
