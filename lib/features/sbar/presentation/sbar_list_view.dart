import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/page_title.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../iam/application/auth_notifier.dart';
import '../../iam/application/users_notifier.dart';
import '../../iam/domain/user.dart';
import '../../patient/application/patient_notifier.dart';
import '../../patient/domain/patient.dart';
import '../application/sbar_notifier.dart';
import '../domain/sbar_transfer.dart';

class SbarListView extends ConsumerStatefulWidget {
  const SbarListView({super.key});

  @override
  ConsumerState<SbarListView> createState() => _SbarListViewState();
}

class _SbarListViewState extends ConsumerState<SbarListView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(sbarNotifierProvider.notifier).load();
      ref.read(patientNotifierProvider.notifier).load();
      ref.read(usersNotifierProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sbarNotifierProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRegisterDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo traspaso'),
      ),
      body: Column(
        children: [
          const PageTitle('Traspasos SBAR'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(sbarNotifierProvider.notifier).load(),
              child: AsyncValueView<SbarState>(
                loading: state.loading,
                error: null,
                data: state,
                isEmpty: (s) => s.transfers.isEmpty,
                emptyMessage: 'No hay traspasos SBAR registrados todavía.',
                builder: (context, s) => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: s.transfers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final transfer = s.transfers[index];
                    final patient = ref
                        .read(patientNotifierProvider.notifier)
                        .byId(transfer.patientId);
                    return Card(
                      child: ListTile(
                        onTap: () =>
                            _showDetailDialog(context, transfer, patient),
                        title: Text(transfer.title),
                        subtitle: Text(
                          '${patient?.fullName ?? 'Paciente #${transfer.patientId}'}\n'
                          'S: ${transfer.situation}',
                        ),
                        isThreeLine: true,
                        leading: StatusChip(
                          label: transfer.statusLabel,
                          palette: ClinicalColors.sbarStatus(transfer.status),
                        ),
                        trailing: transfer.canAcknowledge
                            ? IconButton(
                                tooltip: 'Confirmar recepción',
                                icon: const Icon(Icons.check_circle_outline),
                                onPressed: () => _acknowledge(transfer),
                              )
                            : null,
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

  Future<void> _acknowledge(SbarTransfer transfer) async {
    try {
      await ref.read(sbarNotifierProvider.notifier).acknowledge(transfer.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeDioError(e))));
      }
    }
  }

  Future<void> _showDetailDialog(
    BuildContext context,
    SbarTransfer transfer,
    Patient? patient,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(transfer.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                patient?.fullName ?? 'Paciente #${transfer.patientId}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (transfer.registeredBy != null)
                Text(
                  'Registrado por ${transfer.registeredBy}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (_resolveReceiverName(transfer.targetNurseId) != null)
                Text(
                  'Para ${_resolveReceiverName(transfer.targetNurseId)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 16),
              _SbarSection(label: 'Situación', value: transfer.situation),
              _SbarSection(label: 'Antecedentes', value: transfer.background),
              _SbarSection(label: 'Evaluación', value: transfer.assessment),
              _SbarSection(
                label: 'Recomendación',
                value: transfer.recommendation,
              ),
              if (transfer.additionalNotes != null) ...[
                const Divider(height: 24),
                _SbarSection(
                  label: 'Notas de atención',
                  value: transfer.additionalNotes!,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
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
      builder: (context) =>
          _RegisterSbarDialog(patients: patients, nurses: _receiverOptions()),
    );
  }

  List<User> _receiverOptions() {
    final currentUserId = ref.read(authNotifierProvider).user?.id;
    return ref
        .read(usersNotifierProvider)
        .users
        .where(
          (user) =>
              user.roles.contains(kRoleNurse) && user.id != currentUserId,
        )
        .toList();
  }

  String? _resolveReceiverName(String? targetNurseId) {
    if (targetNurseId == null) return null;
    final users = ref.read(usersNotifierProvider).users;
    for (final user in users) {
      if (user.id == targetNurseId) return user.username;
    }
    return null;
  }
}

class _SbarSection extends StatelessWidget {
  const _SbarSection({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppTheme.primary),
          ),
          const SizedBox(height: 2),
          Text(value.isEmpty ? '—' : value),
        ],
      ),
    );
  }
}

class _RegisterSbarDialog extends ConsumerStatefulWidget {
  const _RegisterSbarDialog({required this.patients, required this.nurses});

  final List<Patient> patients;
  final List<User> nurses;

  @override
  ConsumerState<_RegisterSbarDialog> createState() =>
      _RegisterSbarDialogState();
}

class _RegisterSbarDialogState extends ConsumerState<_RegisterSbarDialog> {
  final _formKey = GlobalKey<FormState>();
  late Patient _patient = widget.patients.first;
  User? _nurse;
  final _situation = TextEditingController();
  final _background = TextEditingController();
  final _assessment = TextEditingController();
  final _recommendation = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _situation.dispose();
    _background.dispose();
    _assessment.dispose();
    _recommendation.dispose();
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
          .read(sbarNotifierProvider.notifier)
          .register(
            RegisterSbarCommand(
              patientId: _patient.id,
              title: 'SBAR - ${_patient.fullName}',
              situation: _situation.text.trim(),
              background: _background.text.trim(),
              assessment: _assessment.text.trim(),
              recommendation: _recommendation.text.trim(),
              targetNurseId: _nurse?.id,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = describeDioError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Requerido' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo traspaso SBAR'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
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
                DropdownButtonFormField<User>(
                  initialValue: _nurse,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Personal receptor',
                  ),
                  items: [
                    for (final nurse in widget.nurses)
                      DropdownMenuItem(
                        value: nurse,
                        child: Text(nurse.username),
                      ),
                  ],
                  validator: (value) =>
                      value == null ? 'Requerido' : null,
                  onChanged: (value) => setState(() => _nurse = value),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _situation,
                  decoration: const InputDecoration(
                    labelText: 'S — Situación actual',
                  ),
                  maxLines: 2,
                  validator: _required,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _background,
                  decoration: const InputDecoration(
                    labelText: 'B — Antecedentes',
                  ),
                  maxLines: 2,
                  validator: _required,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _assessment,
                  decoration: const InputDecoration(
                    labelText: 'A — Evaluación',
                  ),
                  maxLines: 2,
                  validator: _required,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _recommendation,
                  decoration: const InputDecoration(
                    labelText: 'R — Recomendación',
                  ),
                  maxLines: 2,
                  validator: _required,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
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
