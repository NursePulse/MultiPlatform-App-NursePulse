import '../../../shared/widgets/vital_metrics.dart';
import '../../../shared/widgets/page_action.dart';
import '../../../core/localization/app_strings.dart';

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
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListPageBody(
          header: [
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr('Signos vitales'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _query,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: context.tr('Buscar paciente'),
                      helperText: context.tr('Nombre, documento o riesgo'),
                      helperMaxLines: 3,
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
                      '${records.length} de ${state.records.length} registros',
                    ),
                  ),
                ],
              ),
            ),
            if (canRecord)
              PageAction(
                child: FilledButton.icon(
                  onPressed:
                      state.saving ||
                          patientState.loading ||
                          patientState.patients.isEmpty
                      ? null
                      : () => showVitalSignFormSheet(context),
                  icon: Icon(Icons.add),
                  label: Text(context.tr('Registrar')),
                ),
              ),
            if (state.loading || state.saving || patientState.loading)
              LinearProgressIndicator(),
            if (state.warning != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: Text(context.tr(state.warning!))),
                    IconButton(
                      tooltip: context.tr('Cerrar aviso'),
                      icon: Icon(Icons.close),
                      onPressed: () => ref
                          .read(vitalSignNotifierProvider.notifier)
                          .clearWarning(),
                    ),
                  ],
                ),
              ),
            if (state.error != null || patientState.error != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr(state.error ?? patientState.error!),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          state.loading || state.saving || patientState.loading
                          ? null
                          : _refresh,
                      child: Text(context.tr('Reintentar')),
                    ),
                  ],
                ),
              ),
            if (canRecord &&
                !patientState.loading &&
                patientState.error == null &&
                patientState.patients.isEmpty)
              Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  context.tr(
                    'Registra un paciente para asociar signos vitales.',
                  ),
                ),
              ),
          ],
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: records.isEmpty ? 1 : records.length,
              itemBuilder: (context, index) {
                if (records.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      context.tr(
                        state.loading
                            ? 'Cargando signos vitales…'
                            : state.error != null
                            ? 'No se pudo cargar el historial.'
                            : state.records.isEmpty
                            ? 'No hay signos vitales registrados.'
                            : 'No hay coincidencias.',
                      ),
                    ),
                  );
                }

                final s = records[index];
                final p = patients[s.patientId];

                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p?.fullName ?? context.tr('Paciente #${s.patientId}'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SizedBox(height: 12),
                        StatusChip(
                          label: s.riskLabel,
                          palette: _riskPalette(s.riskLevel),
                        ),
                        SizedBox(height: 8),
                        MetadataLine(
                          Icons.schedule,
                          DateFormat('dd/MM/yyyy HH:mm')
                              .format(s.recordedAt.toLocal()),
                        ),
                        SizedBox(height: 12),
                        VitalMetrics(s),
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
