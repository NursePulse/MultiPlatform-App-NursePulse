import '../../../core/localization/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/patient_notifier.dart';
import '../domain/patient.dart';
import '../domain/patient_rules.dart';

Future<void> showPatientFormSheet(BuildContext context, {Patient? editing}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PatientFormSheet(editing: editing),
    );

class PatientFormSheet extends ConsumerStatefulWidget {
  const PatientFormSheet({super.key, this.editing});

  final Patient? editing;

  @override
  ConsumerState<PatientFormSheet> createState() => _PatientFormSheetState();
}

class _PatientFormSheetState extends ConsumerState<PatientFormSheet> {
  final _form = GlobalKey<FormState>();

  late final _first = TextEditingController(text: widget.editing?.firstName);
  late final _last = TextEditingController(text: widget.editing?.lastName);
  late final _document = TextEditingController(
    text: widget.editing?.documentNumber,
  );
  late final _diagnosis = TextEditingController(
    text: widget.editing?.diagnosis,
  );
  late final _room = TextEditingController(text: widget.editing?.roomNumber);
  late final _bed = TextEditingController(text: widget.editing?.bedNumber);

  late DateTime? _birth = widget.editing?.birthDate;
  late DateTime? _admission =
      widget.editing?.admissionDate ?? PatientRules.day(DateTime.now());
  late String? _gender = widget.editing?.gender;
  late String? _physician = widget.editing?.attendingPhysician;
  late PatientStatus _status =
      widget.editing?.status ?? PatientStatus.observation;

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_first, _last, _document, _diagnosis, _room, _bed]) {
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
      final command = RegisterPatientCommand(
        firstName: _first.text,
        lastName: _last.text,
        documentNumber: _document.text,
        birthDate: _birth!,
        gender: _gender!,
        diagnosis: _diagnosis.text,
        roomNumber: _room.text,
        bedNumber: _bed.text,
        attendingPhysician: _physician!,
        status: _status,
        admissionDate: _admission,
      );

      final notifier = ref.read(patientNotifierProvider.notifier);

      if (widget.editing == null) {
        await notifier.create(command);
      } else {
        await notifier.update(widget.editing!.id, command);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Paciente guardado.'))),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = describePatientError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _text(
    TextEditingController c,
    String label,
    String key,
    String? Function(String?) validator, {
    TextInputType? keyboard,
    int lines = 1,
  }) => Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: ValueKey(key),
      controller: c,
      enabled: !_busy,
      decoration: InputDecoration(labelText: context.tr(label)),
      validator: (value) => context.validation(validator(value)),
      keyboardType: keyboard,
      maxLines: lines,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    ),
  );

  Widget _date(
    String label,
    String key,
    DateTime? value,
    String? Function(DateTime?) validator,
    void Function(DateTime) change,
  ) => Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: FormField<DateTime>(
      key: ValueKey(key),
      initialValue: value,
      validator: (value) => context.validation(validator(value)),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      builder: (field) => InkWell(
        onTap: _busy
            ? null
            : () async {
                final first = DateTime(1930);
                final last = PatientRules.day(DateTime.now());
                final current = value ?? DateTime(last.year - 30);
                final initial = current.isBefore(first)
                    ? first
                    : current.isAfter(last)
                    ? last
                    : current;

                final picked = await showDatePicker(
                  context: context,
                  firstDate: first,
                  lastDate: last,
                  initialDate: initial,
                  helpText: context.tr(label),
                );

                if (!mounted || picked == null) return;
                setState(() => change(picked));
                field.didChange(picked);
              },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: context.tr(label),
            errorText: context.validation(field.errorText),
            suffixIcon: Icon(Icons.calendar_today_outlined),
          ),
          child: Text(
            context.tr(
              value == null
                  ? 'Seleccionar'
                  : '${value.day}/${value.month}/${value.year}',
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(patientPermissionsProvider);
    final allowed = widget.editing == null
        ? permissions.create
        : permissions.update;
    final doctors = ref.watch(patientDoctorsProvider);
    final saving = ref.watch(patientNotifierProvider.select((s) => s.saving));

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
                  context.tr(
                    widget.editing == null
                        ? 'Nuevo paciente'
                        : 'Editar paciente',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 16),
                _text(
                  _first,
                  'Nombre',
                  'patient-first',
                  (v) => PatientRules.name(v, 'Nombre'),
                ),
                _text(
                  _last,
                  'Apellido',
                  'patient-last',
                  (v) => PatientRules.name(v, 'Apellido'),
                ),
                _text(_document, 'Documento', 'patient-document', (v) {
                  final error = PatientRules.document(v);
                  if (error != null) return error;

                  return PatientRules.duplicate(
                        ref.read(patientNotifierProvider).patients,
                        v!,
                        excludingId: widget.editing?.id,
                      )
                      ? 'Ya existe un paciente con ese documento.'
                      : null;
                }, keyboard: TextInputType.number),
                _date(
                  'Fecha de nacimiento',
                  'patient-birth',
                  _birth,
                  (v) => PatientRules.birth(v),
                  (v) => _birth = v,
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey('patient-gender'),
                  initialValue: PatientRules.genders.containsKey(_gender)
                      ? _gender
                      : null,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: context.tr('Género')),
                  items: [
                    for (final entry in PatientRules.genders.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(context.tr(entry.value)),
                      ),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _gender = v),
                  validator: (v) => context.validation(
                    v == null ? 'Selecciona un género.' : null,
                  ),
                ),
                SizedBox(height: 12),
                _text(
                  _diagnosis,
                  'Diagnóstico',
                  'patient-diagnosis',
                  (v) => PatientRules.text(v, 'Diagnóstico', 180),
                  lines: 3,
                ),
                _text(
                  _room,
                  'Habitación',
                  'patient-room',
                  (v) => PatientRules.text(v, 'Habitación', 20),
                ),
                _text(
                  _bed,
                  'Cama',
                  'patient-bed',
                  (v) => PatientRules.text(v, 'Cama', 20),
                ),
                doctors.when(
                  loading: () => Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(context.tr('Cargando médicos…')),
                  ),
                  error: (error, _) => Column(
                    children: [
                      Text(context.tr(describePatientError(error))),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => ref.invalidate(patientDoctorsProvider),
                        child: Text(context.tr('Reintentar médicos')),
                      ),
                    ],
                  ),
                  data: (names) {
                    final options = {
                      ...names,
                      if (widget.editing != null)
                        widget.editing!.attendingPhysician,
                    }.toList();

                    return DropdownButtonFormField<String>(
                      key: ValueKey('physicians-${options.join('|')}'),
                      initialValue: options.contains(_physician)
                          ? _physician
                          : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.tr('Médico tratante'),
                      ),
                      items: [
                        for (final name in options)
                          DropdownMenuItem(
                            value: name,
                            child: Text(name, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _physician = v),
                      validator: (v) => context.validation(
                        PatientRules.text(v, 'Médico tratante', 120),
                      ),
                    );
                  },
                ),
                if (doctors.asData?.value.isEmpty == true &&
                    widget.editing == null)
                  Text(
                    context.tr(
                      'No hay médicos disponibles. Un administrador debe asignar ese rol.',
                    ),
                  ),
                SizedBox(height: 12),
                DropdownButtonFormField<PatientStatus>(
                  initialValue: _status,
                  decoration: InputDecoration(labelText: context.tr('Estado')),
                  isExpanded: true,
                  items: [
                    for (final status in PatientStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(context.patientStatus(status.label)),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _status = v ?? _status),
                ),
                SizedBox(height: 12),
                _date(
                  'Fecha de ingreso',
                  'patient-admission',
                  _admission,
                  (v) => PatientRules.admission(v),
                  (v) => _admission = v,
                ),
                if (!allowed)
                  Text(
                    context.tr('No tienes permisos para guardar pacientes.'),
                  ),
                if (_error != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      context.tr(_error!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                FilledButton(
                  key: ValueKey('patient-save'),
                  onPressed:
                      _busy || saving || !allowed || doctors.asData == null
                      ? null
                      : _submit,
                  child: Text(
                    context.tr(_busy ? 'Guardando…' : 'Guardar paciente'),
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
