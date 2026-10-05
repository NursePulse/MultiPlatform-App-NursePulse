import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../patient/application/patient_notifier.dart';
import '../application/sbar_notifier.dart';
import '../domain/sbar_rules.dart';
import '../domain/sbar_transfer.dart';

Future<void> showSbarForm(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => const SbarFormDialog(),
);

class SbarFormDialog extends ConsumerStatefulWidget {
  const SbarFormDialog({super.key});
  @override
  ConsumerState<SbarFormDialog> createState() => _SbarFormDialogState();
}

class _SbarFormDialogState extends ConsumerState<SbarFormDialog> {
  final _form = GlobalKey<FormState>();
  final _situation = TextEditingController(),
      _background = TextEditingController(),
      _assessment = TextEditingController(),
      _recommendation = TextEditingController();
  String? _patientId, _receiverId, _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in [
      _situation,
      _background,
      _assessment,
      _recommendation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy ||
        ref.read(sbarNotifierProvider).saving ||
        !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final patient = ref
          .read(patientNotifierProvider.notifier)
          .byId(_patientId!);
      if (patient == null) {
        throw const FormatException(
          'El paciente seleccionado ya no está disponible.',
        );
      }
      await ref
          .read(sbarNotifierProvider.notifier)
          .register(
            RegisterSbarCommand(
              patientId: patient.id,
              targetNurseId: _receiverId,
              title: 'SBAR - ${patient.fullName}',
              situation: _situation.text,
              background: _background.text,
              assessment: _assessment.text,
              recommendation: _recommendation.text,
            ),
          );
      if (mounted) {
        final warning = ref.read(sbarNotifierProvider).warning;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(warning ?? 'Traspaso SBAR guardado.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = describeSbarError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _section(
    TextEditingController controller,
    String label,
    String key,
    bool blocked,
  ) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      key: ValueKey(key),
      controller: controller,
      enabled: !blocked,
      maxLines: 3,
      maxLength: 1000,
      maxLengthEnforcement: MaxLengthEnforcement.none,
      decoration: InputDecoration(
        labelText: label,
        helperText: '8–1000 caracteres',
      ),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) => SbarRules.section(value, label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(patientNotifierProvider);
    final directory = ref.watch(sbarReceiversProvider);
    final receivers = directory.valueOrNull ?? [];
    final allowed = ref.watch(sbarCanManageProvider);
    final blocked =
        _busy || ref.watch(sbarNotifierProvider.select((s) => s.saving));
    final patientSelected = patients.patients.any((p) => p.id == _patientId);
    final receiverSelected = receivers.any((u) => u.id == _receiverId);
    return PopScope(
      canPop: !blocked,
      child: AlertDialog(
        scrollable: true,
        title: const Text('Nuevo traspaso SBAR'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'sbar-patient-${patients.patients.map((p) => p.id).join(',')}',
                    ),
                    initialValue: patientSelected ? _patientId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Paciente'),
                    items: [
                      for (final p in patients.patients)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            '${p.fullName} · Hab. ${p.roomNumber}',
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
                        : null,
                  ),
                  if (patients.loading) const LinearProgressIndicator(),
                  if (patients.error != null) Text(patients.error!),
                  if (patients.error != null || patients.patients.isEmpty)
                    TextButton(
                      onPressed: blocked || patients.loading
                          ? null
                          : () => ref
                                .read(patientNotifierProvider.notifier)
                                .load(),
                      child: const Text('Recargar pacientes'),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'sbar-receiver-${receivers.map((u) => u.id).join(',')}',
                    ),
                    initialValue: receiverSelected ? _receiverId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Personal receptor',
                    ),
                    items: [
                      for (final u in receivers)
                        DropdownMenuItem(
                          value: u.id,
                          child: Text(
                            u.username,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: blocked
                        ? null
                        : (value) => setState(() => _receiverId = value),
                    validator: (value) =>
                        value == null || !receivers.any((u) => u.id == value)
                        ? 'Selecciona un receptor Nurse disponible.'
                        : null,
                  ),
                  if (directory.isLoading) const LinearProgressIndicator(),
                  if (directory.hasError)
                    Text(describeSbarError(directory.error!)),
                  if (!directory.isLoading &&
                      !directory.hasError &&
                      receivers.isEmpty)
                    const Text(
                      'No hay receptores Nurse distintos del usuario actual.',
                    ),
                  if (directory.hasError || receivers.isEmpty)
                    TextButton(
                      onPressed: blocked || directory.isLoading
                          ? null
                          : () => ref.invalidate(sbarUsersProvider),
                      child: const Text('Recargar receptores'),
                    ),
                  _section(
                    _situation,
                    'S — Situación',
                    'sbar-situation',
                    blocked,
                  ),
                  _section(
                    _background,
                    'B — Antecedentes',
                    'sbar-background',
                    blocked,
                  ),
                  _section(
                    _assessment,
                    'A — Evaluación',
                    'sbar-assessment',
                    blocked,
                  ),
                  _section(
                    _recommendation,
                    'R — Recomendación',
                    'sbar-recommendation',
                    blocked,
                  ),
                  if (!allowed)
                    const Text('No tienes permiso para registrar traspasos.'),
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
        ),
        actions: [
          TextButton(
            key: const ValueKey('sbar-cancel'),
            onPressed: blocked ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('sbar-save'),
            onPressed:
                blocked ||
                    !allowed ||
                    patients.loading ||
                    patients.patients.isEmpty ||
                    directory.isLoading ||
                    directory.hasError ||
                    receivers.isEmpty
                ? null
                : _submit,
            child: Text(_busy ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
    );
  }
}
