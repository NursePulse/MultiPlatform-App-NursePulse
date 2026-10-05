import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../patient/application/patient_notifier.dart';
import '../application/alert_notifier.dart';
import '../domain/alert.dart';
import '../domain/alert_rules.dart';

Future<void> showAlertForm(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => const AlertFormDialog(),
);

class AlertFormDialog extends ConsumerStatefulWidget {
  const AlertFormDialog({super.key});
  @override
  ConsumerState<AlertFormDialog> createState() => _AlertFormDialogState();
}

class _AlertFormDialogState extends ConsumerState<AlertFormDialog> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  String? _patientId, _error;
  String _type = AlertType.cardiac;
  AlertSeverity _severity = AlertSeverity.critical;
  bool _busy = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy ||
        ref.read(alertNotifierProvider).saving ||
        !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(alertNotifierProvider.notifier)
          .create(
            patientId: _patientId!,
            type: _type,
            severity: _severity,
            description: _description.text,
          );
      if (mounted) {
        final warning = ref.read(alertNotifierProvider).warning;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(warning ?? 'Alerta guardada.')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = describeAlertError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(patientNotifierProvider);
    final allowed = ref.watch(alertCanManageProvider);
    final blocked =
        _busy || ref.watch(alertNotifierProvider.select((s) => s.saving));
    final selected = patients.patients.any((p) => p.id == _patientId);
    return PopScope(
      canPop: !blocked,
      child: AlertDialog(
        scrollable: true,
        title: const Text('Registrar alerta'),
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
                      'alert-patient-${patients.patients.map((p) => p.id).join(',')}',
                    ),
                    initialValue: selected ? _patientId : null,
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
                    key: const ValueKey('alert-type'),
                    initialValue: _type,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de alerta',
                    ),
                    items: [
                      for (final type in AlertType.values)
                        DropdownMenuItem(
                          value: type,
                          child: Text(AlertType.label(type)),
                        ),
                    ],
                    onChanged: blocked
                        ? null
                        : (value) => setState(() => _type = value!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AlertSeverity>(
                    key: const ValueKey('alert-severity'),
                    initialValue: _severity,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Severidad'),
                    items: [
                      for (final severity in AlertSeverity.values)
                        DropdownMenuItem(
                          value: severity,
                          child: Text(severity.label),
                        ),
                    ],
                    onChanged: blocked
                        ? null
                        : (value) => setState(() => _severity = value!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('alert-description'),
                    controller: _description,
                    enabled: !blocked,
                    maxLines: 3,
                    maxLength: 255,
                    maxLengthEnforcement: MaxLengthEnforcement.none,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      helperText: '1–255 caracteres',
                    ),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: AlertRules.description,
                  ),
                  if (!allowed)
                    const Text('No tienes permiso para registrar alertas.'),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: blocked ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed:
                blocked ||
                    !allowed ||
                    patients.loading ||
                    patients.error != null ||
                    patients.patients.isEmpty
                ? null
                : _submit,
            child: Text(blocked ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
    );
  }
}
