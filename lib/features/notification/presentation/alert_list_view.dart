import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/list_page_body.dart';
import '../../../shared/widgets/page_title.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../patient/application/patient_notifier.dart';
import '../application/alert_notifier.dart';
import '../domain/alert.dart';
import '../domain/alert_rules.dart';
import 'alert_detail_dialog.dart';
import 'alert_form_dialog.dart';

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
  AlertFilter _filter = AlertFilter.all;
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(alertNotifierProvider.notifier).load();
      if (ref.read(alertCanManageProvider)) {
        ref.read(patientNotifierProvider.notifier).load();
      }
    });
  }

  Future<void> _handle(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeAlertError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(alertNotifierProvider);
    final allowed = ref.watch(alertCanManageProvider);
    final canClose = ref.watch(alertCanCloseProvider);
    final patients = ref.watch(patientNotifierProvider).patients;
    final alerts = AlertRules.filter(state.alerts, _filter);
    return Scaffold(
      floatingActionButton: allowed
          ? FloatingActionButton.extended(
              onPressed: state.saving ? null : () => showAlertForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Registrar alerta'),
            )
          : null,
      body: SafeArea(
        child: ListPageBody(
          header: [
            const PageTitle('Alertas'),
            Text(
              '${state.alerts.where((a) => a.isActive).length} alertas pendientes',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final filter in AlertFilter.values)
                    ChoiceChip(
                      label: Text(filter.label),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                ],
              ),
            ),
            if (state.loading || state.saving) const LinearProgressIndicator(),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: Text(state.error!)),
                    TextButton(
                      onPressed: state.loading || state.saving
                          ? null
                          : () =>
                                ref.read(alertNotifierProvider.notifier).load(),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            if (state.warning != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: Text(state.warning!)),
                    IconButton(
                      tooltip: 'Cerrar aviso',
                      onPressed: () => ref
                          .read(alertNotifierProvider.notifier)
                          .clearWarning(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
          ],
          child: RefreshIndicator(
            onRefresh: () => ref.read(alertNotifierProvider.notifier).load(),
            child: alerts.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No hay alertas en este filtro.'),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: alerts.length,
                    itemBuilder: (context, index) {
                      final alert = alerts[index];
                      var name = 'Paciente #${alert.patientId}';
                      for (final patient in patients) {
                        if (patient.id == alert.patientId) {
                          name = patient.fullName;
                        }
                      }
                      final attendConfirmed = state.confirmedActions.contains(
                        '${alert.id}:ATTENDED',
                      );
                      final closeConfirmed = state.confirmedActions.contains(
                        '${alert.id}:CLOSED',
                      );
                      final pending = state.savingId == alert.id;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(alert.title),
                              Text(alert.description),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  StatusChip(
                                    label: alert.severityLabel,
                                    palette: _severityPalette(alert.severity),
                                  ),
                                  StatusChip(
                                    label: alert.statusLabel,
                                    palette: ClinicalColors.alertStatus(
                                      alert.status.wireValue,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                alert.triggeredAt == null
                                    ? 'Generada: sin información'
                                    : 'Generada: ${DateFormat('dd/MM/yyyy HH:mm').format(alert.triggeredAt!.toLocal())}',
                              ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: () => showDialog<void>(
                                      context: context,
                                      builder: (_) =>
                                          AlertDetailDialog(alertId: alert.id),
                                    ),
                                    child: const Text('Ver detalle'),
                                  ),
                                  if (allowed &&
                                      alert.status == AlertStatus.open &&
                                      !attendConfirmed)
                                    TextButton(
                                      onPressed: state.saving
                                          ? null
                                          : () => _handle(
                                              () => ref
                                                  .read(
                                                    alertNotifierProvider
                                                        .notifier,
                                                  )
                                                  .attend(alert.id),
                                            ),
                                      child: Text(
                                        pending ? 'Procesando…' : 'Atender',
                                      ),
                                    ),
                                  if (canClose &&
                                      alert.status == AlertStatus.attended &&
                                      !closeConfirmed)
                                    TextButton(
                                      onPressed: state.saving
                                          ? null
                                          : () => _handle(
                                              () => ref
                                                  .read(
                                                    alertNotifierProvider
                                                        .notifier,
                                                  )
                                                  .close(alert.id),
                                            ),
                                      child: Text(
                                        pending ? 'Procesando…' : 'Cerrar',
                                      ),
                                    ),
                                ],
                              ),
                              if (alert.status == AlertStatus.attended &&
                                  !canClose)
                                const Text('Pendiente de cierre médico.'),
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
