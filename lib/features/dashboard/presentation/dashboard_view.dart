import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/page_title.dart';
import '../../iam/application/auth_notifier.dart';
import '../application/dashboard_notifier.dart';

final _timeFormat = DateFormat('HH:mm');

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(dashboardNotifierProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardNotifierProvider);
    final username = ref.watch(authNotifierProvider).user?.username ?? '';
    return Scaffold(
      body: Column(
        children: [
          const PageTitle('Dashboard'),
          Expanded(child: _DashboardBody(state: state, username: username)),
        ],
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.state, required this.username});

  final DashboardState state;
  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
        onRefresh: () => ref.read(dashboardNotifierProvider.notifier).load(),
        child: AsyncValueView<DashboardState>(
          loading: state.loading,
          error: state.error,
          data: state,
          isEmpty: (s) => s.summary == null,
          onRetry: () => ref.read(dashboardNotifierProvider.notifier).load(),
          builder: (context, s) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Hola, $username',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Actualizado a las ${_timeFormat.format(s.summary!.lastUpdate)}'
                '${s.isFallback ? ' · calculado localmente' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 3 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _SummaryTile(
                    label: 'Pacientes monitoreados',
                    value: s.summary!.monitoredPatients,
                    icon: Icons.groups_rounded,
                    color: AppTheme.primary,
                  ),
                  _SummaryTile(
                    label: 'Alertas activas',
                    value: s.summary!.activeAlerts,
                    icon: Icons.notifications_active_rounded,
                    color: ClinicalColors.severityModerate.foreground,
                  ),
                  _SummaryTile(
                    label: 'Alertas críticas',
                    value: s.summary!.criticalAlerts,
                    icon: Icons.emergency_rounded,
                    color: ClinicalColors.severityCritical.foreground,
                  ),
                  _SummaryTile(
                    label: 'Alertas moderadas',
                    value: s.summary!.moderateAlerts,
                    icon: Icons.warning_amber_rounded,
                    color: ClinicalColors.riskMedium.foreground,
                  ),
                  _SummaryTile(
                    label: 'Eventos clínicos hoy',
                    value: s.summary!.clinicalEventsToday,
                    icon: Icons.description_rounded,
                    color: AppTheme.primaryAlt,
                  ),
                  _SummaryTile(
                    label: 'Controles este mes',
                    value: s.summary!.inspectionsThisMonth,
                    icon: Icons.monitor_heart_rounded,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
  }
}

class _SummaryTile extends StatelessWidget {

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const Spacer(),
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
