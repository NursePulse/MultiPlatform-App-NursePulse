import '../../../shared/widgets/page_action.dart';
import '../../../core/localization/app_strings.dart';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/list_page_body.dart';
import '../../../shared/widgets/page_title.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/clinical_card.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(describeAlertError(e)))),
        );
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
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListPageBody(
          header: [
            PageTitle(
              'Alertas',
              subtitle:
                  '${state.alerts.where((a) => a.isActive).length} alertas pendientes',
            ),
            if (allowed)
              PageAction(
                child: FilledButton.icon(
                  onPressed: state.saving ? null : () => showAlertForm(context),
                  icon: Icon(Icons.add),
                  label: Text(context.tr('Registrar alerta')),
                ),
              ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final filter in AlertFilter.values)
                    ChoiceChip(
                      label: Text(context.tr(filter.label)),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                ],
              ),
            ),
            if (state.loading || state.saving) LinearProgressIndicator(),
            if (state.error != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: Text(context.tr(state.error!))),
                    TextButton(
                      onPressed: state.loading || state.saving
                          ? null
                          : () =>
                                ref.read(alertNotifierProvider.notifier).load(),
                      child: Text(context.tr('Reintentar')),
                    ),
                  ],
                ),
              ),
            if (state.warning != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: Text(context.tr(state.warning!))),
                    IconButton(
                      tooltip: context.tr('Cerrar aviso'),
                      onPressed: () => ref
                          .read(alertNotifierProvider.notifier)
                          .clearWarning(),
                      icon: Icon(Icons.close),
                    ),
                  ],
                ),
              ),
          ],
          child: RefreshIndicator(
            onRefresh: () => ref.read(alertNotifierProvider.notifier).load(),
            child: alerts.isEmpty
                ? ListView(
                    physics: AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          context.tr('No hay alertas en este filtro.'),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: alerts.length,
                    itemBuilder: (context, index) {
                      final alert = alerts[index];
                      var name = context.tr('Paciente #${alert.patientId}');
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
                      return ClinicalCard(
                        cardKey: ValueKey('alert-card-${alert.id}'),
                        accent: _severityPalette(alert.severity).foreground,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .primary,
                                child: Icon(Icons.person_outline),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    Text(
                                      context.tr(
                                        alert.triggeredAt == null
                                            ? 'Generada: sin información'
                                            : 'Generada: ${DateFormat('dd/MM/yyyy HH:mm').format(alert.triggeredAt!.toLocal())}',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            alert.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          SizedBox(height: 8),
                          Text(alert.description),
                          SizedBox(height: 12),
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
                          SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (_) =>
                                      AlertDetailDialog(alertId: alert.id),
                                ),
                                child: Text(context.tr('Ver detalle')),
                              ),
                              if (allowed &&
                                  alert.status == AlertStatus.open &&
                                  !attendConfirmed)
                                FilledButton(
                                  onPressed: state.saving
                                      ? null
                                      : () => _handle(
                                          () => ref
                                              .read(
                                                alertNotifierProvider.notifier,
                                              )
                                              .attend(alert.id),
                                        ),
                                  child: Text(
                                    context.tr(
                                      pending ? 'Procesando…' : 'Atender',
                                    ),
                                  ),
                                ),
                              if (canClose &&
                                  alert.status == AlertStatus.attended &&
                                  !closeConfirmed)
                                FilledButton(
                                  onPressed: state.saving
                                      ? null
                                      : () => _handle(
                                          () => ref
                                              .read(
                                                alertNotifierProvider.notifier,
                                              )
                                              .close(alert.id),
                                        ),
                                  child: Text(
                                    context.tr(
                                      pending ? 'Procesando…' : 'Cerrar',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (alert.status == AlertStatus.attended &&
                              !canClose) ...[
                            SizedBox(height: 12),
                            Text(
                              context.tr('Pendiente de cierre médico.'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
