import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/dashboard/domain/dashboard_rules.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/patient/domain/patient.dart';

import '../notification/fixtures.dart' as alerts;
import 'fixtures.dart';

void main() {
  for (final staff in [nurse, doctor, admin]) {
    test(
      '${staff.username}: lecturas y navegación conforme a roles reales',
      () {
        expect(DashboardRules.canRead(staff.roles), isTrue);
        expect(DashboardRules.canReadAudit(staff.roles), staff != nurse);
        for (final path in [
          '/patients',
          '/alerts',
          '/clinical-events',
          '/patients/1/monitoring',
        ]) {
          expect(DashboardRules.canNavigate(staff, path), isTrue);
        }
        for (final path in ['/reports', '/audit']) {
          expect(DashboardRules.canNavigate(staff, path), staff != nurse);
        }
        expect(
          DashboardRules.actions(staff)
              .every((a) => DashboardRules.canNavigate(staff, a.path)),
          isTrue,
        );
        expect(
          DashboardRules.modules(staff),
          staff == admin
              ? 8
              : staff == doctor
              ? 5
              : 6,
        );
      },
    );
  }
  test('sin sesión o rol no hay accesos ni autorización de lectura', () {
    const unknown = User(id: '7', username: 'unknown', roles: []);
    for (final staff in [null, unknown]) {
      expect(DashboardRules.actions(staff), isEmpty);
      expect(DashboardRules.canNavigate(staff, '/patients'), isFalse);
      expect(DashboardRules.canRead(staff?.roles ?? []), isFalse);
    }
    expect(DashboardRules.modules(unknown), 0);
  });
  test('perfil principal y permisos no dependen de un modo visual', () {
    const staff = User(
      id: '7',
      username: 'multi.test',
      roles: [kRoleNurse, kRoleAdmin],
    );
    expect(DashboardRules.modules(staff), 8);
    expect(DashboardRules.actions(staff).map((a) => a.path), [
      '/reports',
      '/audit',
      '/alerts',
    ]);
  });
  for (final path in [
    '/unknown',
    '/patients/0/monitoring',
    '/patients/abc/monitoring',
    '/patients/-1/monitoring',
  ]) {
    test('ruta inválida $path no autorizada por acciones Dashboard', () {
      expect(DashboardRules.canNavigate(nurse, path), isFalse);
    });
  }
  test('solo excluye pacientes de alta; prioridad coincide con críticos', () {
    final snapshot = data(
      patients: [
        patient(status: PatientStatus.stable),
        patient(id: '2', status: PatientStatus.observation),
        patient(id: '3', status: PatientStatus.critical),
        patient(id: '4', status: PatientStatus.discharged),
      ],
    );
    final summary = DashboardRules.summarize(snapshot, now);
    expect(summary.monitoredPatients, 3);
    expect(summary.criticalPatients, 1);
  });
  test('OPEN y ATTENDED activos; CLOSED excluido; moderadas = no críticas', () {
    final summary = DashboardRules.summarize(
      data(
        alerts: [
          alerts.alert(),
          alerts.alert(id: '2', status: 'ATTENDED'),
          alerts.alert(id: '3', severity: 'HIGH'),
          alerts.alert(id: '4', severity: 'MEDIUM'),
          alerts.alert(id: '5', severity: 'LOW'),
          alerts.alert(id: '6', status: 'CLOSED'),
        ],
      ),
      now,
    );
    expect(summary.activeAlerts, 5);
    expect(summary.criticalAlerts, 2);
    expect(summary.moderateAlerts, 3);
  });
  test('día y mes: límites inclusivos y año correcto', () {
    final clock = DateTime(2027, 1, 1, 12);
    final summary = DashboardRules.summarize(
      data(
        events: [
          event(date: DateTime(2027, 1, 1)),
          event(id: '2', date: DateTime(2027, 1, 1, 23, 59, 59)),
          event(id: '3', date: DateTime(2026, 12, 31, 23, 59, 59)),
          event(id: '4', date: DateTime(2027, 1, 2)),
        ],
        vitals: [
          vital(date: DateTime(2027, 1, 1)),
          vital(id: '2', date: DateTime(2027, 1, 31, 23, 59, 59)),
          vital(id: '3', date: DateTime(2026, 1, 1)),
          vital(id: '4', date: DateTime(2027, 2, 1)),
        ],
      ),
      clock,
    );
    expect(summary.clinicalEventsToday, 2);
    expect(summary.inspectionsThisMonth, 2);
    expect(summary.lastUpdate, clock);
  });
  test('fechas UTC se comparan después de convertir a hora local', () {
    final clock = DateTime(2027, 1, 1, 12);
    final summary = DashboardRules.summarize(
      data(
        events: [
          event(date: DateTime(2027, 1, 1, 0, 1).toUtc()),
          event(id: '2', date: DateTime(2026, 12, 31, 23, 59).toUtc()),
        ],
        vitals: [vital(date: DateTime(2027, 1, 1, 0, 1).toUtc())],
      ),
      clock.toUtc(),
    );
    expect(summary.clinicalEventsToday, 1);
    expect(summary.inspectionsThisMonth, 1);
  });
  test(
    'vacío real produce ceros; auditoría no consultada o fallida no es cero',
    () {
      final summary = DashboardRules.summarize(data(), now);
      expect(summary.monitoredPatients, 0);
      expect(summary.activeAlerts, 0);
      expect(summary.auditMovements, isNull);
      expect(DashboardRules.summarize(data(audits: []), now).auditMovements, 0);
      expect(
        DashboardRules.summarize(
          data(auditError: 'Error simulado'),
          now,
        ).auditMovements,
        isNull,
      );
    },
  );
  test(
    'alertas por fecha real; fechas ausentes al final y sin inventarlas',
    () {
      final sorted = DashboardRules.sortedAlerts([
        alerts.alert(id: '1', date: null),
        alerts.alert(id: '2', date: '2026-10-03T12:00:00'),
        alerts.alert(id: '3'),
      ]);
      expect(sorted.map((a) => a.id), ['3', '2', '1']);
      expect(sorted.last.triggeredAt, isNull);
    },
  );

  test(
    'última actualización prioriza auditoría incluso ante alerta más nueva',
    () {
      final auditDate = DateTime(2026, 10, 2, 9).toUtc();
      final alertDate = DateTime(2026, 10, 3, 20).toUtc();
      final summary = DashboardRules.summarize(
        data(
          audits: [audit(date: auditDate)],
          alerts: [alerts.alert(date: alertDate.toIso8601String())],
        ),
        now,
      );
      expect(summary.lastUpdate, auditDate);
    },
  );

  for (final logs in [null, <dynamic>[]]) {
    test(
      'auditoría ${logs == null ? 'ausente' : 'vacía'} usa fecha de alerta, incluso cerrada',
      () {
        final alertDate = DateTime(2026, 10, 3, 20).toUtc();
        final summary = DashboardRules.summarize(
          data(
            audits: logs == null ? null : [],
            alerts: [
              alerts.alert(status: 'CLOSED', date: alertDate.toIso8601String()),
            ],
          ),
          now,
        );
        expect(summary.lastUpdate, alertDate);
        expect(summary.activeAlerts, 0);
      },
    );
  }

  test('alerta sin fecha y sin auditoría usa reloj de consulta, como web', () {
    final summary = DashboardRules.summarize(
      data(alerts: [alerts.alert(date: null)]),
      now,
    );
    expect(summary.lastUpdate, now);
  });

  test(
    'fecha de signos/eventos no reemplaza auditoría o alertas en actualización',
    () {
      final summary = DashboardRules.summarize(
        data(
          events: [event(date: now.add(const Duration(days: 1)))],
          vitals: [vital(date: now.add(const Duration(days: 1)))],
        ),
        now,
      );
      expect(summary.lastUpdate, now);
    },
  );
}
