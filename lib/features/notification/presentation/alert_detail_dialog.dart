import '../../../core/localization/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/alert_notifier.dart';

class AlertDetailDialog extends ConsumerWidget {
  const AlertDetailDialog({super.key, required this.alertId});
  final String alertId;
  static String _date(DateTime? date) => date == null
      ? 'Sin información'
      : DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(alertDetailProvider(alertId));
    return AlertDialog(
      title: Text(context.tr('Detalle de alerta')),
      content: SizedBox(
        width: 420,
        child: detail.when(
          loading: () => Center(child: CircularProgressIndicator()),
          error: (error, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr(describeAlertError(error))),
              TextButton(
                onPressed: () => ref.invalidate(alertDetailProvider(alertId)),
                child: Text(context.tr('Reintentar detalle')),
              ),
            ],
          ),
          data: (alert) => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  alert.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(context.tr('Paciente #${alert.patientId}')),
                Text(alert.description),
                Text(
                  context.tr('Severidad: ${context.tr(alert.severityLabel)}'),
                ),
                Text(context.tr('Estado: ${context.tr(alert.statusLabel)}')),
                Text(context.tr('Generada por: ${alert.triggeredBy}')),
                Text(context.tr('Generada: ${_date(alert.triggeredAt)}')),
                if (alert.attendedBy != null)
                  Text(context.tr('Atendida por: ${alert.attendedBy}')),
                if (alert.attendedAt != null)
                  Text(context.tr('Atendida: ${_date(alert.attendedAt)}')),
                if (alert.closedBy != null)
                  Text(context.tr('Cerrada por: ${alert.closedBy}')),
                if (alert.closedAt != null)
                  Text(context.tr('Cerrada: ${_date(alert.closedAt)}')),
                if (alert.resolutionNotes != null)
                  Text(context.tr('Resolución: ${alert.resolutionNotes}')),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('Volver')),
        ),
      ],
    );
  }
}
