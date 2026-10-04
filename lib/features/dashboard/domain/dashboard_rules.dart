import '../../iam/domain/user.dart';
import '../../notification/domain/alert.dart';
import '../../patient/domain/patient.dart';
import 'dashboard_summary.dart';

class DashboardLink {
  const DashboardLink(this.path, this.label);
  final String path, label;
}

class DashboardRules {
  static bool canRead(List<String> roles) =>
      roles.any([kRoleNurse, kRoleDoctor, kRoleAdmin].contains);
  static bool canReadAudit(List<String> roles) =>
      roles.any([kRoleDoctor, kRoleAdmin].contains);

  // Catálogo del perfil de la web; no es una comprobación de conexión a APIs.
  static int modules(User user) => switch (user.primaryRole) {
    kRoleAdmin => 8,
    kRoleDoctor => 5,
    kRoleNurse => 6,
    _ => 0,
  };

  static List<DashboardLink> actions(User? user) {
    if (!canRead(user?.roles ?? const [])) return const [];
    return switch (user!.primaryRole) {
      kRoleAdmin => const [
        DashboardLink('/reports', 'Ver reportes'),
        DashboardLink('/audit', 'Ver auditoría'),
        DashboardLink('/alerts', 'Ver alertas'),
      ],
      kRoleDoctor => const [
        DashboardLink('/patients', 'Ver pacientes'),
        DashboardLink('/clinical-events', 'Eventos clínicos'),
        DashboardLink('/reports', 'Ver reportes'),
        DashboardLink('/alerts', 'Ver alertas'),
      ],
      _ => const [
        DashboardLink('/patients', 'Ver pacientes'),
        DashboardLink('/vital-signs', 'Registrar signos vitales'),
        DashboardLink('/clinical-events', 'Eventos clínicos'),
        DashboardLink('/sbar', 'Entrega de turno SBAR'),
        DashboardLink('/alerts', 'Ver alertas'),
      ],
    };
  }

  static bool canNavigate(User? user, String path) {
    if (!canRead(user?.roles ?? const [])) return false;
    if (path == '/audit' || path == '/reports') {
      return canReadAudit(user!.roles);
    }
    return const [
          '/patients',
          '/alerts',
          '/vital-signs',
          '/clinical-events',
          '/sbar',
        ].contains(path) ||
        RegExp(r'^/patients/[1-9]\d*/monitoring$').hasMatch(path);
  }

  static List<Alert> sortedAlerts(Iterable<Alert> alerts) =>
      alerts.toList()..sort((a, b) {
        if (a.triggeredAt == null) return b.triggeredAt == null ? 0 : 1;
        if (b.triggeredAt == null) return -1;
        return b.triggeredAt!.compareTo(a.triggeredAt!);
      });

  static DashboardSummary summarize(DashboardData data, DateTime now) {
    final localNow = now.toLocal();
    final activeAlerts = data.alerts.where((a) => a.isActive).toList();
    bool today(DateTime date) {
      final local = date.toLocal();
      return local.year == localNow.year &&
          local.month == localNow.month &&
          local.day == localNow.day;
    }

    bool month(DateTime date) {
      final local = date.toLocal();
      return local.year == localNow.year && local.month == localNow.month;
    }

    return DashboardSummary(
      monitoredPatients: data.patients
          .where((p) => p.status != PatientStatus.discharged)
          .length,
      criticalPatients: data.patients
          .where((p) => p.status == PatientStatus.critical)
          .length,
      activeAlerts: activeAlerts.length,
      criticalAlerts: activeAlerts.where((a) => a.isCritical).length,
      moderateAlerts: activeAlerts.where((a) => !a.isCritical).length,
      clinicalEventsToday: data.events.where((e) => today(e.occurredAt)).length,
      inspectionsThisMonth: data.vitals
          .where((v) => month(v.recordedAt))
          .length,
      auditMovements: data.audits?.length,
      // Hora de la consulta completada; no sustituye fechas de registros clínicos.
      lastUpdate: now,
    );
  }
}
