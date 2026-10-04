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
      title: const Text('Detalle de alerta'),
      content: SizedBox(
        width: 420,
        child: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(describeAlertError(error)),
              TextButton(
                onPressed: () => ref.invalidate(alertDetailProvider(alertId)),
                child: const Text('Reintentar detalle'),
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
                Text('Paciente #${alert.patientId}'),
                Text(alert.description),
                Text('Severidad: ${alert.severityLabel}'),
                Text('Estado: ${alert.statusLabel}'),
                Text('Generada por: ${alert.triggeredBy}'),
                Text('Generada: ${_date(alert.triggeredAt)}'),
                if (alert.attendedBy != null)
                  Text('Atendida por: ${alert.attendedBy}'),
                if (alert.attendedAt != null)
                  Text('Atendida: ${_date(alert.attendedAt)}'),
                if (alert.closedBy != null)
                  Text('Cerrada por: ${alert.closedBy}'),
                if (alert.closedAt != null)
                  Text('Cerrada: ${_date(alert.closedAt)}'),
                if (alert.resolutionNotes != null)
                  Text('Resolución: ${alert.resolutionNotes}'),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Volver'),
        ),
      ],
    );
  }
}
