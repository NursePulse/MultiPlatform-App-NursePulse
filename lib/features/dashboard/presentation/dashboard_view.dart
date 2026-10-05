import '../../../shared/widgets/list_page_body.dart';
import '../../../core/localization/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_title.dart';
import '../../../shared/widgets/responsive_panels.dart';
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
    final allowed = DashboardRules.canRead(user?.roles ?? []);
    final summary = allowed ? state.summary : null;
    final data = allowed ? state.data : null;
    final isAdmin = user?.primaryRole == kRoleAdmin;
    Future<void> reload() =>
        ref.read(dashboardNotifierProvider.notifier).load();
    Widget retry(String error, String key) => Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(error),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            key: ValueKey(key),
            onPressed: state.loading ? null : reload,
            child: Text(context.tr('Reintentar')),
          ),
        ],
      ),
    );
    Widget heading(String title, String path) => Padding(
      padding: EdgeInsets.only(top: 24, bottom: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        children: [
          Text(
            context.tr(title),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          TextButton(
            onPressed: () => _go(context, user, path),
            child: Text(context.tr('Ver todo')),
          ),
        ],
      ),
    );
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListPageBody(
          header: [
            PageTitle(
              'Dashboard',
              subtitle: switch (user?.primaryRole) {
                kRoleAdmin => 'Resumen administrativo',
                kRoleDoctor => 'Resumen médico',
                kRoleNurse => 'Resumen de enfermería',
                _ => 'Sin acceso clínico',
              },
            ),
            if (state.loading) LinearProgressIndicator(),
          ],
          child: RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                if (!allowed)
                  Text(
                    context.tr(
                      'No tienes permiso para consultar el Dashboard.',
                    ),
                  ),
                if (allowed && state.error != null)
                  retry(state.error!, 'dashboard-retry'),
                if (summary != null && data != null) ...[
                  Text(
                    context.tr(
                      'Última actualización: ${DateFormat('dd/MM/yyyy HH:mm').format(summary.lastUpdate.toLocal())}',
                    ),
                  ),
                  if (state.error != null)
                    Text(
                      context.tr(
                        'Se muestran los datos de la última consulta completada.',
                      ),
                    ),
                  SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final textScale =
                          MediaQuery.textScalerOf(context).scale(14) / 14;
                      final columns =
                          constraints.maxWidth >= 900 && textScale < 1.5
                          ? 4
                          : constraints.maxWidth >= 700
                          ? 2
                          : constraints.maxWidth >= 280 && textScale < 1.5
                          ? 2
                          : 1;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 12) / columns;
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
                      final cards = [
                        for (final metric in metrics)
                          Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        metric.$3,
                                        color: switch (metric.$1) {
                                          'Alertas críticas' =>
                                            ClinicalColors
                                                .riskCritical
                                                .foreground,
                                          'Alertas moderadas' =>
                                            ClinicalColors
                                                .riskMedium
                                                .foreground,
                                          'Pacientes prioritarios' =>
                                            ClinicalColors.riskHigh.foreground,
                                          _ => Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        },
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          context.tr(
                                            metric.$2?.toString() ?? '—',
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    context.tr(metric.$1),
                                    key: ValueKey('metric-${metric.$1}'),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontSize: 14, height: 1.35),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ];
                      return Column(
                        children: [
                          for (var row = 0; row < cards.length; row += columns)
                            Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (
                                      var index = row;
                                      index < row + columns &&
                                          index < cards.length;
                                      index++
                                    ) ...[
                                      if (index > row) SizedBox(width: 12),
                                      SizedBox(
                                        width: width,
                                        child: cards[index],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  ResponsivePanels(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          heading('Seguimiento de pacientes', '/patients'),
                          if (data.patients.isEmpty)
                            Text(context.tr('No hay pacientes registrados.')),
                          for (final patient in data.patients.take(5))
                            Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  foregroundColor: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                  child: Text(patient.initials),
                                ),
                                title: Text(patient.fullName),
                                subtitle: Text(
                                  context.tr(
                                    '${patient.code} · ${context.patientStatus(patient.statusLabel)}\n${context.tr('Hab. ${patient.roomNumber} · Cama ${patient.bedNumber}')}\n${patient.diagnosis}',
                                  ),
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
                                trailing: Icon(Icons.chevron_right),
                              ),
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          heading('Alertas activas recientes', '/alerts'),
                          if (!data.alerts.any((a) => a.isActive))
                            Text(context.tr('No hay alertas activas.')),
                          for (final alert
                              in data.alerts.where((a) => a.isActive).take(5))
                            Card(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data.patients
                                              .where(
                                                (p) => p.id == alert.patientId,
                                              )
                                              .firstOrNull
                                              ?.fullName ??
                                          context.tr(
                                            'Paciente #${alert.patientId}',
                                          ),
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
                                      context.tr(
                                        alert.triggeredAt == null
                                            ? 'Generada: sin información'
                                            : 'Generada: ${DateFormat('dd/MM/yyyy HH:mm').format(alert.triggeredAt!.toLocal())}',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (isAdmin) ...[
                    heading('Auditoría reciente', '/audit'),
                    if (data.auditError != null)
                      retry(
                        'No se pudo cargar la auditoría: ${data.auditError}',
                        'dashboard-audit-retry',
                      ),
                    if (data.audits != null && data.audits!.isEmpty)
                      Text(context.tr('No hay movimientos de auditoría.')),
                    for (final log in data.audits?.take(5) ?? <AuditLog>[])
                      Card(
                        child: ListTile(
                          title: Text(
                            context.tr(
                              '${context.tr(log.actionLabel)} · ${context.tr(log.entityLabel)} #${log.entityId}',
                            ),
                          ),
                          subtitle: Text(
                            context.tr(
                              '${log.performedBy}\n${DateFormat('dd/MM/yyyy HH:mm').format(log.performedAt.toLocal())}',
                            ),
                          ),
                          isThreeLine: true,
                        ),
                      ),
                  ],
                ],
                if (allowed) ...[
                  Padding(
                    padding: EdgeInsets.only(top: 24, bottom: 8),
                    child: Text(
                      context.tr('Accesos rápidos'),
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
                          child: Text(context.tr(action.label)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
