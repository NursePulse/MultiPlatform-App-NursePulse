import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_title.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../audit/domain/audit_log.dart';
import '../../iam/domain/user.dart';
import '../../notification/domain/alert.dart';
import '../application/dashboard_notifier.dart';
import '../domain/dashboard_rules.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  void _go(BuildContext context, User? user, String path) {
    if (DashboardRules.canNavigate(user, path)) context.go(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardNotifierProvider);
    final user = ref.watch(dashboardUserProvider);
    final allowed = DashboardRules.canRead(user?.roles ?? const []);
    final summary = allowed ? state.summary : null;
    final data = allowed ? state.data : null;
    final isAdmin = user?.primaryRole == kRoleAdmin;
    Future<void> reload() =>
        ref.read(dashboardNotifierProvider.notifier).load();
    Widget retry(String error, String key) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            key: ValueKey(key),
            onPressed: state.loading ? null : reload,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
    Widget heading(String title, String path) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          TextButton(
            onPressed: () => _go(context, user, path),
            child: const Text('Ver todo'),
          ),
        ],
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PageTitle('Dashboard'),
            if (state.loading) const LinearProgressIndicator(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: reload,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Hola, ${user?.username ?? ''}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(switch (user?.primaryRole) {
                      kRoleAdmin => 'Resumen administrativo',
                      kRoleDoctor => 'Resumen médico',
                      kRoleNurse => 'Resumen de enfermería',
                      _ => 'Sin acceso clínico',
                    }),
                    if (!allowed)
                      const Text(
                        'No tienes permiso para consultar el Dashboard.',
                      ),
                    if (allowed && state.error != null)
                      retry(state.error!, 'dashboard-retry'),
                    if (summary != null && data != null) ...[
                      Text(
                        'Última actualización: ${DateFormat('dd/MM/yyyy HH:mm').format(summary.lastUpdate.toLocal())}',
                      ),
                      if (state.error != null)
                        const Text(
                          'Se muestran los datos de la última consulta completada.',
                        ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 700
                              ? 3
                              : constraints.maxWidth >= 340
                              ? 2
                              : 1;
                          final width =
                              (constraints.maxWidth - (columns - 1) * 12) /
                              columns;
                          final metrics = [
                            (
                              'Pacientes monitoreados',
                              summary.monitoredPatients,
                              Icons.groups_rounded,
                            ),
                            (
                              'Alertas activas',
                              summary.activeAlerts,
                              Icons.notifications_active_rounded,
                            ),
                            (
                              'Alertas críticas',
                              summary.criticalAlerts,
                              Icons.emergency_rounded,
                            ),
                            (
                              'Alertas moderadas',
                              summary.moderateAlerts,
                              Icons.warning_amber_rounded,
                            ),
                            if (isAdmin)
                              (
                                'Movimientos de auditoría consultados',
                                summary.auditMovements,
                                Icons.fact_check_rounded,
                              )
                            else
                              (
                                'Pacientes prioritarios',
                                summary.criticalPatients,
                                Icons.priority_high,
                              ),
                            (
                              'Módulos del perfil',
                              DashboardRules.modules(user!),
                              Icons.apps,
                            ),
                            (
                              'Eventos clínicos hoy',
                              summary.clinicalEventsToday,
                              Icons.description_rounded,
                            ),
                            (
                              'Controles este mes',
                              summary.inspectionsThisMonth,
                              Icons.monitor_heart_rounded,
                            ),
                          ];
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final metric in metrics)
                                SizedBox(
                                  width: width,
                                  child: Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            metric.$3,
                                            color: AppTheme.primary,
                                          ),
                                          Text(
                                            metric.$2?.toString() ?? '—',
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineMedium,
                                          ),
                                          Text(
                                            metric.$1,
                                            key: ValueKey(
                                              'metric-${metric.$1}',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      heading('Seguimiento de pacientes', '/patients'),
                      if (data.patients.isEmpty)
                        const Text('No hay pacientes registrados.'),
                      for (final patient in data.patients.take(5))
                        Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(patient.initials),
                            ),
                            title: Text(patient.fullName),
                            subtitle: Text(
                              '${patient.code} · ${patient.statusLabel}\nHab. ${patient.roomNumber} / Cama ${patient.bedNumber}\n${patient.diagnosis}',
                            ),
                            isThreeLine: true,
                            onTap:
                                DashboardRules.canNavigate(
                                  user,
                                  '/patients/${patient.id}/monitoring',
                                )
                                ? () => _go(
                                    context,
                                    user,
                                    '/patients/${patient.id}/monitoring',
                                  )
                                : null,
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        ),
                      heading('Alertas activas recientes', '/alerts'),
                      if (!data.alerts.any((a) => a.isActive))
                        const Text('No hay alertas activas.'),
                      for (final alert
                          in data.alerts.where((a) => a.isActive).take(5))
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data.patients
                                          .where((p) => p.id == alert.patientId)
                                          .firstOrNull
                                          ?.fullName ??
                                      'Paciente #${alert.patientId}',
                                ),
                                Text(alert.title),
                                Text(alert.description),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    StatusChip(
                                      label: alert.severityLabel,
                                      palette: alert.isCritical
                                          ? ClinicalColors.riskCritical
                                          : ClinicalColors.riskMedium,
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
                              ],
                            ),
                          ),
                        ),
                      if (isAdmin) ...[
                        heading('Auditoría reciente', '/audit'),
                        if (data.auditError != null)
                          retry(
                            'No se pudo cargar la auditoría: ${data.auditError}',
                            'dashboard-audit-retry',
                          ),
                        if (data.audits != null && data.audits!.isEmpty)
                          const Text('No hay movimientos de auditoría.'),
                        for (final log
                            in data.audits?.take(5) ?? const <AuditLog>[])
                          Card(
                            child: ListTile(
                              title: Text(
                                '${log.actionLabel} · ${log.entityLabel} #${log.entityId}',
                              ),
                              subtitle: Text(
                                '${log.performedBy}\n${DateFormat('dd/MM/yyyy HH:mm').format(log.performedAt.toLocal())}',
                              ),
                              isThreeLine: true,
                            ),
                          ),
                      ],
                    ],
                    if (allowed) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 8),
                        child: Text(
                          'Accesos rápidos',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final action in DashboardRules.actions(user))
                            OutlinedButton(
                              key: ValueKey('dashboard-${action.path}'),
                              onPressed: () => _go(context, user, action.path),
                              child: Text(action.label),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
