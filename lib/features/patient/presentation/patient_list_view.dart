import '../../../core/localization/app_strings.dart';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/list_page_body.dart';
import '../../../shared/widgets/status_chip.dart';

import '../application/patient_notifier.dart';
import '../domain/patient.dart';
import '../domain/patient_rules.dart';
import 'patient_form_sheet.dart';

class PatientListView extends ConsumerStatefulWidget {
  const PatientListView({super.key});

  @override
  ConsumerState<PatientListView> createState() => _PatientListViewState();
}

class _PatientListViewState extends ConsumerState<PatientListView> {
  final _query = TextEditingController();
  bool _confirming = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (mounted) ref.read(patientNotifierProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _action(Patient patient, String action) async {
    if (_confirming || ref.read(patientNotifierProvider).saving) return;

    if (action == 'edit') {
      await showPatientFormSheet(context, editing: patient);
      return;
    }

    _confirming = true;
    final deleting = action == 'delete';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr(deleting ? 'Eliminar paciente' : 'Dar de alta')),
        content: Text(
          context.tr(
            deleting
                ? '¿Eliminar a ${patient.fullName}? Esta acción es permanente.'
                : '¿Dar de alta a ${patient.fullName}?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr(deleting ? 'Eliminar' : 'Dar de alta')),
          ),
        ],
      ),
    );

    _confirming = false;
    if (!mounted || confirmed != true) return;

    try {
      final notifier = ref.read(patientNotifierProvider.notifier);

      if (deleting) {
        await notifier.delete(patient.id);
      } else {
        await notifier.discharge(patient.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                deleting ? 'Paciente eliminado.' : 'Paciente dado de alta.',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(describePatientError(e)))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(patientNotifierProvider);
    final permissions = ref.watch(patientPermissionsProvider);

    final patients = state.patients
        .where((p) => PatientRules.matches(p, _query.text))
        .toList();

    return Scaffold(
      floatingActionButton: permissions.create
          ? FloatingActionButton.extended(
              onPressed: state.saving
                  ? null
                  : () => showPatientFormSheet(context),
              icon: Icon(Icons.add),
              label: Text(context.tr('Nuevo paciente')),
            )
          : null,
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListPageBody(
          header: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr('Pacientes'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _query,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: context.tr(
                        'Buscar por nombre, documento, habitación o estado',
                      ),
                      prefixIcon: Icon(Icons.search),
                      suffixIcon: _query.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: context.tr('Limpiar búsqueda'),
                              onPressed: () => setState(_query.clear),
                              icon: Icon(Icons.close),
                            ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    context.tr(
                      '${patients.length} de ${state.patients.length} pacientes',
                    ),
                  ),
                ],
              ),
            ),
            if (state.loading || state.saving) LinearProgressIndicator(),
            if (state.error != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: Text(context.tr(state.error!))),
                    TextButton(
                      onPressed: state.loading || state.saving
                          ? null
                          : () => ref
                                .read(patientNotifierProvider.notifier)
                                .load(),
                      child: Text(context.tr('Reintentar')),
                    ),
                  ],
                ),
              ),
          ],
          child: RefreshIndicator(
            onRefresh: () => ref.read(patientNotifierProvider.notifier).load(),
            child: ListView.builder(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 0, 16, 96),
              itemCount: patients.isEmpty ? 1 : patients.length,
              itemBuilder: (context, index) {
                if (patients.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      context.tr(
                        state.loading
                            ? 'Cargando pacientes…'
                            : state.error != null
                            ? 'No se pudo cargar el listado.'
                            : state.patients.isEmpty
                            ? 'No hay pacientes registrados.'
                            : 'No hay coincidencias.',
                      ),
                    ),
                  );
                }

                final p = patients[index];

                return Card(
                  child: InkWell(
                    onTap: () => context.push('/patients/${p.id}/monitoring'),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .primary,
                                child: Text(p.initials),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  p.fullName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                              if (permissions.update || permissions.delete)
                                PopupMenuButton<String>(
                                  enabled: !state.saving,
                                  onSelected: (action) => _action(p, action),
                                  itemBuilder: (_) => [
                                    if (permissions.update)
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text(context.tr('Editar')),
                                      ),
                                    if (permissions.update &&
                                        p.status != PatientStatus.discharged)
                                      PopupMenuItem(
                                        value: 'discharge',
                                        child: Text(context.tr('Dar de alta')),
                                      ),
                                    if (permissions.delete)
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text(context.tr('Eliminar')),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              StatusChip(
                                label: context.patientStatus(p.statusLabel),
                                palette: ClinicalColors.patientStatus(
                                  p.statusLabel,
                                ),
                              ),
                              Chip(
                                label: Text(
                                  context.tr(
                                    'Hab. ${p.roomNumber} · Cama ${p.bedNumber}',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            context.tr(
                              '${p.code} · Documento ${p.documentNumber} · ${p.age} años',
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  p.diagnosis,
                                  style: TextStyle(color: AppTheme.textMuted),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
