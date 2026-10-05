import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/status_chip.dart';
import '../application/alert_inbox.dart';
import '../application/alert_notifier.dart';
import '../domain/alert.dart';

void _openAlert(BuildContext context, WidgetRef ref, Alert alert) {
  ref.read(alertInboxProvider.notifier).dismiss();
  context.go('/alerts?alert=${Uri.encodeQueryComponent(alert.id)}');
}

class AlertNotificationButton extends ConsumerWidget {
  const AlertNotificationButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(alertCanManageProvider)) return const SizedBox.shrink();
    final inbox = ref.watch(alertInboxProvider);
    return IconButton(
      key: const ValueKey('alert-notifications'),
      tooltip: context.tr('Notificaciones'),
      icon: Badge.count(
        count: inbox.alerts.length,
        isLabelVisible: inbox.alerts.isNotEmpty,
        child: const Icon(Icons.notifications_outlined, color: Colors.white),
      ),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        constraints: const BoxConstraints(maxWidth: 640),
        builder: (_) => _NotificationSheet(
          onOpen: (alert) {
            Navigator.of(context, rootNavigator: true).pop();
            _openAlert(context, ref, alert);
          },
        ),
      ),
    );
  }
}

class _NotificationSheet extends ConsumerWidget {
  const _NotificationSheet({required this.onOpen});
  final ValueChanged<Alert> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(alertInboxProvider);
    final state = ref.watch(alertNotifierProvider);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            ListTile(
              title: Text(context.tr('Notificaciones')),
              subtitle: Text(
                context.tr('${inbox.alerts.length} alertas pendientes'),
              ),
              trailing: IconButton(
                tooltip: context.tr('Cerrar'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            if (state.loading) const LinearProgressIndicator(),
            if (state.error != null) ...[
              Text(context.tr(state.error!)),
              TextButton(
                onPressed: state.loading
                    ? null
                    : () => ref.read(alertNotifierProvider.notifier).load(),
                child: Text(context.tr('Reintentar')),
              ),
            ],
            if (inbox.alerts.isEmpty && !state.loading)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(context.tr('No hay alertas activas.')),
              ),
            for (final alert in inbox.alerts.take(5))
              ListTile(
                key: ValueKey('notification-alert-${alert.id}'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                leading: Icon(
                  Icons.notifications_active_outlined,
                  color: ClinicalColors.severityAccent(
                    alert.severity.wireValue,
                  ),
                ),
                title: Text(context.tr(alert.title)),
                subtitle: Text(
                  '${context.tr('Paciente #${alert.patientId}')}\n'
                  '${context.tr(alert.severityLabel)} · ${context.tr(alert.statusLabel)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpen(alert),
              ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/alerts');
              },
              child: Text(context.tr('Ver todas las alertas')),
            ),
          ],
        ),
      ),
    );
  }
}

class AlertNotificationBanner extends ConsumerWidget {
  const AlertNotificationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alert = ref.watch(alertInboxProvider).notice;
    if (alert == null) return const SizedBox.shrink();
    return Material(
      color: ClinicalColors.severity(alert.severity.wireValue).background,
      child: InkWell(
        key: const ValueKey('new-alert-banner'),
        onTap: () => _openAlert(context, ref, alert),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
          child: Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                color: ClinicalColors.severityAccent(alert.severity.wireValue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr('Nueva alerta'),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(context.tr('Paciente #${alert.patientId}')),
                    StatusChip(
                      label: context.tr(alert.severityLabel),
                      palette: ClinicalColors.severity(
                        alert.severity.wireValue,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.tr('Cerrar aviso'),
                onPressed: () =>
                    ref.read(alertInboxProvider.notifier).dismiss(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
