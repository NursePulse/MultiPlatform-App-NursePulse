import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../application/patient_notifier.dart';
import '../domain/patient.dart';

Future<void> showPatientFormSheet(BuildContext context, {Patient? editing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => _PatientFormSheet(editing: editing),
  );
}

class _PatientFormSheet extends ConsumerStatefulWidget {
  const _PatientFormSheet({this.editing});

  final Patient? editing;

  @override
  ConsumerState<_PatientFormSheet> createState() => _PatientFormSheetState();
}

class _PatientFormSheetState extends ConsumerState<_PatientFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _firstName = TextEditingController(
    text: widget.editing?.firstName,
  );
  late final _lastName = TextEditingController(text: widget.editing?.lastName);
  late final _document = TextEditingController(
    text: widget.editing?.documentNumber,
  );
  late final _gender = TextEditingController(text: widget.editing?.gender);
  late final _diagnosis = TextEditingController(
    text: widget.editing?.diagnosis,
  );
  late final _room = TextEditingController(text: widget.editing?.roomNumber);
  late final _bed = TextEditingController(text: widget.editing?.bedNumber);
  late final _physician = TextEditingController(
    text: widget.editing?.attendingPhysician,
  );
  late DateTime? _birthDate = widget.editing?.birthDate;
  late PatientStatus _status =
      widget.editing?.status ?? PatientStatus.observation;
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.editing != null;

  @override
  void dispose() {
    for (final c in [
      _firstName,
      _lastName,
      _document,
      _gender,
      _diagnosis,
      _room,
      _bed,
      _physician,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _birthDate == null) {
      if (_birthDate == null)
        setState(() => _error = 'Selecciona la fecha de nacimiento.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final command = RegisterPatientCommand(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      documentNumber: _document.text.trim(),
      birthDate: _birthDate!,
      gender: _gender.text.trim(),
      diagnosis: _diagnosis.text.trim(),
      roomNumber: _room.text.trim(),
      bedNumber: _bed.text.trim(),
      attendingPhysician: _physician.text.trim(),
      status: _status,
      admissionDate: widget.editing?.admissionDate,
    );
    try {
      final notifier = ref.read(patientNotifierProvider.notifier);
      if (_isEditing) {
        await notifier.update(widget.editing!.id, command);
      } else {
        await notifier.create(command);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = describeDioError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isEditing ? 'Editar paciente' : 'Nuevo paciente',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _requiredField(_firstName, 'Nombre'),
              const SizedBox(height: 8),
              _requiredField(_lastName, 'Apellido'),
              const SizedBox(height: 8),
              _requiredField(_document, 'Documento'),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickBirthDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha de nacimiento',
                  ),
                  child: Text(
                    _birthDate == null
                        ? 'Seleccionar'
                        : '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _requiredField(_gender, 'Género'),
              const SizedBox(height: 8),
              _requiredField(_diagnosis, 'Diagnóstico'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _requiredField(_room, 'Habitación')),
                  const SizedBox(width: 8),
                  Expanded(child: _requiredField(_bed, 'Cama')),
                ],
              ),
              const SizedBox(height: 8),
              _requiredField(_physician, 'Médico tratante'),
              if (_isEditing) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<PatientStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: [
                    for (final status in PatientStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _status = value ?? _status),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Guardar cambios' : 'Registrar paciente'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _requiredField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: (value) =>
          (value == null || value.trim().isEmpty) ? 'Campo requerido' : null,
    );
  }
}
