import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/page_title.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../patient/application/patient_notifier.dart';
import '../../patient/domain/patient.dart';
import '../application/vital_sign_notifier.dart';
import '../domain/vital_sign.dart';

ChipPalette _riskPalette(RiskLevel level) => switch (level) {
  RiskLevel.low => ClinicalColors.riskLow,
  RiskLevel.medium => ClinicalColors.riskMedium,
  RiskLevel.high => ClinicalColors.riskHigh,
  RiskLevel.critical => ClinicalColors.riskCritical,
  RiskLevel.unassessed => ClinicalColors.riskUnassessed,
};

class VitalSignListView extends ConsumerStatefulWidget {
  const VitalSignListView({super.key});

  @override
  ConsumerState<VitalSignListView> createState() => _VitalSignListViewState();
}

class _VitalSignListViewState extends ConsumerState<VitalSignListView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(vitalSignNotifierProvider.notifier).load();
      ref.read(patientNotifierProvider.notifier).load();
    });
  }

  String _patientLabel(String patientId) {
    final patient = ref.read(patientNotifierProvider.notifier).byId(patientId);
    return patient?.fullName ?? 'Paciente #$patientId';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vitalSignNotifierProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRecordDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Registrar'),
      ),
      body: Column(
        children: [
          const PageTitle('Signos vitales'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(vitalSignNotifierProvider.notifier).load(),
              child: AsyncValueView<VitalSignState>(
                loading: state.loading,
                error: state.error,
                data: state,
                isEmpty: (s) => s.records.isEmpty,
                onRetry: () =>
                    ref.read(vitalSignNotifierProvider.notifier).load(),
                builder: (context, s) => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: s.records.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final record = s.records[index];
                    return Card(
                      child: ListTile(
                        title: Text(_patientLabel(record.patientId)),
                        subtitle: Text(
                          '${record.bloodPressureFormatted} · ${record.heartRateFormatted} · '
                          '${record.respiratoryRateFormatted} · SpO2 ${record.oxygenSaturation}% · '
                          '${record.temperature}°C',
                        ),
                        isThreeLine: true,
                        trailing: StatusChip(
                          label: record.riskLabel,
                          palette: _riskPalette(record.riskLevel),
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

  Future<void> _showRecordDialog(BuildContext context) async {
    final patients = ref.read(patientNotifierProvider).patients;
    if (patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registra un paciente primero.')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => _RecordVitalSignDialog(patients: patients),
    );
  }
}

class _RecordVitalSignDialog extends ConsumerStatefulWidget {
  const _RecordVitalSignDialog({required this.patients});

  final List<Patient> patients;

  @override
  ConsumerState<_RecordVitalSignDialog> createState() =>
      _RecordVitalSignDialogState();
}

class _RecordVitalSignDialogState
    extends ConsumerState<_RecordVitalSignDialog> {
  final _formKey = GlobalKey<FormState>();
  late Patient _selectedPatient = widget.patients.first;
  final _heartRate = TextEditingController();
  final _respiratoryRate = TextEditingController();
  final _systolic = TextEditingController();
  final _diastolic = TextEditingController();
  final _oxygen = TextEditingController();
  final _temperature = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _heartRate,
      _respiratoryRate,
      _systolic,
      _diastolic,
      _oxygen,
      _temperature,
    ]) {
      c.dispose();
    }
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
          .read(vitalSignNotifierProvider.notifier)
          .record(
            RecordVitalSignCommand(
              patientId: _selectedPatient.id,
              heartRate: num.parse(_heartRate.text),
              respiratoryRate: num.parse(_respiratoryRate.text),
              systolicPressure: num.parse(_systolic.text),
              diastolicPressure: num.parse(_diastolic.text),
              oxygenSaturation: num.parse(_oxygen.text),
              temperature: num.parse(_temperature.text),
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = describeDioError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) =>
          (value == null || num.tryParse(value) == null) ? 'Requerido' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar signos vitales'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Patient>(
                initialValue: _selectedPatient,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Paciente'),
                items: [
                  for (final patient in widget.patients)
                    DropdownMenuItem(
                      value: patient,
                      child: Text(patient.fullName),
                    ),
                ],
                onChanged: (value) => setState(
                  () => _selectedPatient = value ?? _selectedPatient,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _numberField(_heartRate, 'FC (lpm)')),
                  const SizedBox(width: 8),
                  Expanded(child: _numberField(_respiratoryRate, 'FR (rpm)')),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _numberField(_systolic, 'TA sistólica')),
                  const SizedBox(width: 8),
                  Expanded(child: _numberField(_diastolic, 'TA diastólica')),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _numberField(_oxygen, 'SpO2 (%)')),
                  const SizedBox(width: 8),
                  Expanded(child: _numberField(_temperature, 'Temp (°C)')),
                ],
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
