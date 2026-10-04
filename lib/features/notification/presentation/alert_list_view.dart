import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/page_title.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../iam/application/auth_notifier.dart';
import '../../iam/domain/user.dart';
import '../../patient/application/patient_notifier.dart';
import '../../patient/domain/patient.dart';
import '../application/alert_notifier.dart';
import '../domain/alert.dart';

ChipPalette _severityPalette(AlertSeverity severity) => switch (severity) {
  AlertSeverity.low => ClinicalColors.riskLow,
  AlertSeverity.medium => ClinicalColors.riskMedium,
  AlertSeverity.high => ClinicalColors.riskHigh,
  AlertSeverity.critical => ClinicalColors.riskCritical,
};

class AlertListView extends ConsumerStatefulWidget {
  const AlertListView({super.key});

  @override
  ConsumerState<AlertListView> createState() => _AlertListViewState();
}

class _AlertListViewState extends ConsumerState<AlertListView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(alertNotifierProvider.notifier).load();
      ref.read(patientNotifierProvider.notifier).load();
    });
  }

  Future<void> _handle(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeDioError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(alertNotifierProvider);
    final user = ref.watch(authNotifierProvider).user;
    final username = user?.username ?? '';
    final canCloseAlerts = user?.hasAnyRole([kRoleAdmin, kRoleDoctor]) ?? false;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Registrar alerta'),
      ),
      body: Column(
        children: [
          const PageTitle('Alertas'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(alertNotifierProvider.notifier).load(),
              child: AsyncValueView<AlertState>(
                loading: state.loading,
                error: state.error,
                data: state,
                isEmpty: (s) => s.alerts.isEmpty,
                onRetry: () => ref.read(alertNotifierProvider.notifier).load(),
                builder: (context, s) => ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: s.alerts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final alert = s.alerts[index];
                    final patient = ref
                        .read(patientNotifierProvider.notifier)
                        .byId(alert.patientId);
                    return Card(
                      child: ListTile(
                        title: Text(alert.title),
                        subtitle: Text(
                          '${patient?.fullName ?? 'Paciente #${alert.patientId}'}\n${alert.message}',
                        ),
                        isThreeLine: true,
                        leading: StatusChip(
                          label: alert.severityLabel,
                          palette: _severityPalette(alert.severity),
                        ),
                        trailing: _AlertActions(
                          alert: alert,
                          onAttend: alert.status == AlertStatus.open
                              ? () => _handle(
                                  () => ref
                                      .read(alertNotifierProvider.notifier)
                                      .attend(alert.id, username),
                                )
                              : null,
                          onClose:
                              alert.status != AlertStatus.closed &&
                                  canCloseAlerts
                              ? () => _handle(
                                  () => ref
                                      .read(alertNotifierProvider.notifier)
                                      .close(alert.id, username),
                                )
                              : null,
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

  Future<void> _showCreateDialog(BuildContext context) async {
    final patients = ref.read(patientNotifierProvider).patients;
    if (patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registra un paciente primero.')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => _CreateAlertDialog(patients: patients),
    );
  }
}

class _CreateAlertDialog extends ConsumerStatefulWidget {
  const _CreateAlertDialog({required this.patients});

  final List<Patient> patients;

  @override
  ConsumerState<_CreateAlertDialog> createState() => _CreateAlertDialogState();
}

class _CreateAlertDialogState extends ConsumerState<_CreateAlertDialog> {
  final _formKey = GlobalKey<FormState>();
  late Patient _patient = widget.patients.first;
  String _type = AlertType.cardiac;
  AlertSeverity _severity = AlertSeverity.critical;
  final _description = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
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
          .read(alertNotifierProvider.notifier)
          .create(
            patientId: _patient.id,
            type: _type,
            severity: _severity,
            description: _description.text.trim(),
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
      title: const Text('Registrar alerta'),
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
                initialValue: _type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo de alerta'),
                items: [
                  for (final type in AlertType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(AlertType.label(type)),
                    ),
                ],
                onChanged: (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<AlertSeverity>(
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
                onChanged: (value) =>
                    setState(() => _severity = value ?? _severity),
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

class _AlertActions extends StatelessWidget {
  const _AlertActions({required this.alert, this.onAttend, this.onClose});

  final Alert alert;
  final VoidCallback? onAttend;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    if (onAttend == null && onClose == null) {
      return StatusChip(
        label: alert.statusLabel,
        palette: ClinicalColors.alertStatus(alert.status.wireValue),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onAttend != null)
          IconButton(
            tooltip: 'Atender',
            icon: const Icon(Icons.check_circle_outline),
            onPressed: onAttend,
          ),
        if (onClose != null)
          IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close_rounded),
            onPressed: onClose,
          ),
      ],
    );
  }
}
