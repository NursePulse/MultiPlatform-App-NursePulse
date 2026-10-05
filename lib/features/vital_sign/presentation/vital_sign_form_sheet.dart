import '../../../core/localization/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../patient/application/patient_notifier.dart';
import '../application/vital_sign_notifier.dart';
import '../domain/vital_sign_rules.dart';

Future<void> showVitalSignFormSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => VitalSignFormSheet(),
    );

class VitalSignFormSheet extends ConsumerStatefulWidget {
  const VitalSignFormSheet({super.key});

  @override
  ConsumerState<VitalSignFormSheet> createState() => _VitalSignFormSheetState();
}

class _VitalSignFormSheetState extends ConsumerState<VitalSignFormSheet> {
  final _form = GlobalKey<FormState>();

  final _heart = TextEditingController();
  final _respiratory = TextEditingController();
  final _systolic = TextEditingController();
  final _diastolic = TextEditingController();
  final _oxygen = TextEditingController();
  final _temperature = TextEditingController();

  String? _patientId, _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _heart,
      _respiratory,
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
    if (_busy || !_form.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final user = ref.read(vitalSignUserProvider);
      if (user == null) {
        throw FormatException('Inicia sesión de nuevo.');
      }

      final command = VitalSignRules.fromForm(
        patientId: _patientId!,
        nurseId: user.id,
        heartRate: _heart.text,
        respiratoryRate: _respiratory.text,
        systolic: _systolic.text,
        diastolic: _diastolic.text,
        oxygen: _oxygen.text,
        temperature: _temperature.text,
      );

      await ref.read(vitalSignNotifierProvider.notifier).record(command);

      if (mounted) {
        final warning = ref.read(vitalSignNotifierProvider).warning;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr(warning ?? 'Signos vitales guardados.')),
          ),
        );

        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = describeVitalSignError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _number(
    TextEditingController c,
    String label,
    String key,
    num min,
    num max, {
    bool integer = true,
    bool pressure = false,
  }) => Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: ValueKey(key),
      controller: c,
      enabled: !_busy,
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      decoration: InputDecoration(
        labelText: context.tr(label),
        helperText: context.tr('$min–$max${integer ? ' · Entero' : ''}'),
      ),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (v) {
        final error = VitalSignRules.number(
          v,
          label,
          min,
          max,
          integer: integer,
        );
        if (error != null || !pressure) return error;

        final systolic = num.tryParse(_systolic.text.trim());
        final diastolic = num.tryParse(_diastolic.text.trim());

        return systolic == null || diastolic == null
            ? null
            : VitalSignRules.pressure(systolic, diastolic);
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(patientNotifierProvider);
    final canRecord = ref.watch(vitalSignCanRecordProvider);
    final saving = ref.watch(vitalSignNotifierProvider.select((s) => s.saving));

    final validSelection = patients.patients.any((p) => p.id == _patientId);

    return PopScope(
      canPop: !_busy,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .92,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('Registrar signos vitales'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'vital-patient-${patients.patients.map((p) => p.id).join(',')}',
                  ),
                  initialValue: validSelection ? _patientId : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.tr('Paciente'),
                  ),
                  items: [
                    for (final p in patients.patients)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          context.tr('${p.fullName} · Hab. ${p.roomNumber}'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _patientId = value),
                  validator: (value) => context.validation(
                    value == null ||
                            !patients.patients.any((p) => p.id == value)
                        ? 'Selecciona un paciente disponible.'
                        : null,
                  ),
                ),
                if (patients.loading) LinearProgressIndicator(),
                if (patients.error != null) Text(context.tr(patients.error!)),
                if (patients.error != null || patients.patients.isEmpty)
                  TextButton(
                    onPressed: _busy || patients.loading
                        ? null
                        : () =>
                              ref.read(patientNotifierProvider.notifier).load(),
                    child: Text(context.tr('Recargar pacientes')),
                  ),
                SizedBox(height: 12),
                _number(_heart, 'FC (lpm)', 'vital-heart', 20, 250),
                _number(_respiratory, 'FR (rpm)', 'vital-respiratory', 5, 80),
                _number(
                  _systolic,
                  'TA sistólica (mmHg)',
                  'vital-systolic',
                  50,
                  260,
                ),
                _number(
                  _diastolic,
                  'TA diastólica (mmHg)',
                  'vital-diastolic',
                  30,
                  180,
                  pressure: true,
                ),
                _number(_oxygen, 'SpO₂ (%)', 'vital-oxygen', 0, 100),
                _number(
                  _temperature,
                  'Temperatura (°C)',
                  'vital-temperature',
                  30,
                  45,
                  integer: false,
                ),
                if (!canRecord)
                  Text(
                    context.tr(
                      'No tienes permiso para registrar signos vitales.',
                    ),
                  ),
                if (_error != null)
                  Text(
                    context.tr(_error!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                FilledButton(
                  key: ValueKey('vital-save'),
                  onPressed:
                      _busy ||
                          saving ||
                          !canRecord ||
                          patients.loading ||
                          patients.patients.isEmpty
                      ? null
                      : _submit,
                  child: Text(
                    context.tr(_busy ? 'Guardando…' : 'Guardar signos vitales'),
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: Text(context.tr('Cancelar')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
