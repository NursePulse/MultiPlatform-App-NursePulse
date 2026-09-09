import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/page_title.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../iam/application/auth_notifier.dart';
import '../../iam/domain/user.dart';
import '../../patient/application/patient_notifier.dart';
import '../application/alert_notifier.dart';
import '../domain/alert.dart';

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
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(alertNotifierProvider.notifier).load();
      ref.read(patientNotifierProvider.notifier).load();
    });
  }

  Future<void> _handle(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeDioError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(alertNotifierProvider);
    final user = ref.watch(authNotifierProvider).user;
    final username = user?.username ?? '';
    final canCloseAlerts = user?.hasAnyRole([kRoleHeadAdminNurse]) ?? false;
    return Scaffold(
      body: Column(
        children: [
          const PageTitle('Alertas'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(alertNotifierProvider.notifier).load(),
              child: AsyncValueView<AlertState>(
                loading: state.loading,
                error: state.error,
                data: state,
                isEmpty: (s) => s.alerts.isEmpty,
                onRetry: () => ref.read(alertNotifierProvider.notifier).load(),
                builder: (context, s) => ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: s.alerts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final alert = s.alerts[index];
                    final patient = ref
                        .read(patientNotifierProvider.notifier)
                        .byId(alert.patientId);
                    return Card(
                      child: ListTile(
                        title: Text(alert.title),
                        subtitle: Text(
                          '${patient?.fullName ?? 'Paciente #${alert.patientId}'}\n${alert.message}',
                        ),
                        isThreeLine: true,
                        leading: StatusChip(
                          label: alert.severityLabel,
                          palette: _severityPalette(alert.severity),
                        ),
                        trailing: _AlertActions(
                          alert: alert,
                          onAttend: alert.status == AlertStatus.open
                              ? () => _handle(
                                  () => ref
                                      .read(alertNotifierProvider.notifier)
                                      .attend(alert.id, username),
                                )
                              : null,
                          onClose:
                              alert.status != AlertStatus.closed &&
                                  canCloseAlerts
                              ? () => _handle(
                                  () => ref
                                      .read(alertNotifierProvider.notifier)
                                      .close(alert.id, username),
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertActions extends StatelessWidget {
  const _AlertActions({required this.alert, this.onAttend, this.onClose});

  final Alert alert;
  final VoidCallback? onAttend;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    if (onAttend == null && onClose == null) {
      return StatusChip(
        label: alert.statusLabel,
        palette: ClinicalColors.alertStatus(alert.status.wireValue),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onAttend != null)
          IconButton(
            tooltip: 'Atender',
            icon: const Icon(Icons.check_circle_outline),
            onPressed: onAttend,
          ),
        if (onClose != null)
          IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close_rounded),
            onPressed: onClose,
          ),
      ],
    );
  }
}
