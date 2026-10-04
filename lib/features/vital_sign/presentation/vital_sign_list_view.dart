import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/list_page_body.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../patient/application/patient_notifier.dart';
import '../../patient/domain/patient.dart';
import '../application/vital_sign_notifier.dart';
import '../domain/vital_sign.dart';
import 'vital_sign_form_sheet.dart';

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
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _refresh() => Future.wait<void>([
    ref.read(vitalSignNotifierProvider.notifier).load(),
    ref.read(patientNotifierProvider.notifier).load(),
  ]);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vitalSignNotifierProvider);
    final patientState = ref.watch(patientNotifierProvider);
    final canRecord = ref.watch(vitalSignCanRecordProvider);

    final patients = <String, Patient>{
      for (final p in patientState.patients) p.id: p,
    };
    final query = _query.text.trim().toLowerCase();

    final records = state.records.where((s) {
      final p = patients[s.patientId];

      return '${p?.fullName ?? ''} ${p?.documentNumber ?? ''} '
              '${p?.roomNumber ?? ''} ${p?.code ?? ''} '
              '${s.patientId} ${s.riskLabel}'
          .toLowerCase()
          .contains(query);
    }).toList();

    return Scaffold(
      floatingActionButton: canRecord
          ? FloatingActionButton.extended(
              onPressed:
                  state.saving ||
                      patientState.loading ||
                      patientState.patients.isEmpty
                  ? null
                  : () => showVitalSignFormSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Registrar'),
            )
          : null,
      body: SafeArea(
        child: ListPageBody(
          header: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Signos vitales',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _query,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Buscar paciente, documento o riesgo',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              onPressed: () => setState(_query.clear),
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${records.length} de ${state.records.length} registros',
                  ),
                ],
              ),
            ),
            if (state.loading || state.saving || patientState.loading)
              const LinearProgressIndicator(),
            if (state.warning != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: Text(state.warning!)),
                    IconButton(
                      tooltip: 'Cerrar aviso',
                      icon: const Icon(Icons.close),
                      onPressed: () => ref
                          .read(vitalSignNotifierProvider.notifier)
                          .clearWarning(),
                    ),
                  ],
                ),
              ),
            if (state.error != null || patientState.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: Text(state.error ?? patientState.error!)),
                    TextButton(
                      onPressed:
                          state.loading || state.saving || patientState.loading
                          ? null
                          : _refresh,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            if (canRecord &&
                !patientState.loading &&
                patientState.error == null &&
                patientState.patients.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Registra un paciente para asociar signos vitales.',
                ),
              ),
          ],
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              itemCount: records.isEmpty ? 1 : records.length,
              itemBuilder: (context, index) {
                if (records.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      state.loading
                          ? 'Cargando signos vitales…'
                          : state.error != null
                          ? 'No se pudo cargar el historial.'
                          : state.records.isEmpty
                          ? 'No hay signos vitales registrados.'
                          : 'No hay coincidencias.',
                    ),
                  );
                }

                final s = records[index];
                final p = patients[s.patientId];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p?.fullName ?? 'Paciente #${s.patientId}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        StatusChip(
                          label: s.riskLabel,
                          palette: _riskPalette(s.riskLevel),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm')
                              .format(s.recordedAt.toLocal()),
                        ),
                        Text(
                          'FC: ${s.heartRate} lpm · FR: ${s.respiratoryRate} rpm',
                        ),
                        Text('TA: ${s.systolic}/${s.diastolic} mmHg'),
                        Text(
                          'SpO₂: ${s.oxygenSaturation} % · '
                          'Temperatura: ${s.temperature} °C',
                        ),
                      ],
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
