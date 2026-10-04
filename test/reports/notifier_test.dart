import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/audit/domain/audit_log.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/patient/domain/patient.dart';
import 'package:nurse_pulse_app/features/report/domain/report.dart';

import '../notification/fixtures.dart' as notification;
import '../sbar/fixtures.dart' as sbar;
import 'fixtures.dart';

void main() {
  for (final actor in [
    null,
    nurse,
    const User(id: '7', username: 'unknown.test', roles: ['UNKNOWN']),
  ]) {
    test(
      'sin permiso ${actor?.primaryRole} no lee almacenamiento ni consulta recursos',
      () async {
        final memory = MemoryReports(), sources = Sources();
        final n = notifier(memory, sources, actor: actor);
        addTearDown(n.dispose);
        await n.load();
        await expectLater(generate(n), throwsFormatException);
        expect(memory.reads, 0);
        expect(memory.writes, 0);
        expect(sources.calls, isEmpty);
        expect(n.state.reports, isEmpty);
      },
    );
  }
  for (final form in [
    ('', now, now, ReportType.general),
    ('   ', now, now, ReportType.general),
    ('Título', null, now, ReportType.general),
    ('Título', now, null, ReportType.general),
    ('Título', now.add(const Duration(days: 1)), now, ReportType.general),
    ('Título', now, now, 'UNKNOWN'),
  ]) {
    test(
      'formulario inválido rechaza antes de cualquier llamada ${form.$1}/${form.$4}/${form.$2}',
      () async {
        final memory = MemoryReports(), sources = Sources();
        final audit = AuditCalls();
        final n = notifier(memory, sources, audit: audit);
        addTearDown(n.dispose);
        await expectLater(
          n.generate(
            type: form.$4,
            title: form.$1,
            startDate: form.$2,
            endDate: form.$3,
          ),
          throwsFormatException,
        );
        expect(sources.calls, isEmpty);
        expect(memory.writes, 0);
        expect(audit.actions, isEmpty);
        expect(n.state.generating, isFalse);
      },
    );
  }
  for (final actor in [doctor, admin]) {
    test(
      '${actor.primaryRole} genera y restaura localmente con auditoría válida',
      () async {
        final memory = MemoryReports(), sources = Sources();
        final audit = AuditCalls();
        final n = notifier(memory, sources, actor: actor, audit: audit);
        addTearDown(n.dispose);
        final created = await generate(n);
        expect(created.title, 'Reporte ficticio');
        expect(created.generatedBy, 'Equipo clínico');
        expect(created.status, ReportStatus.completed);
        expect(created.summary!.patients, 1);
        expect(audit.actions, ['VIEW', 'UPDATE']);
        expect(audit.actors, [actor.username, actor.username]);
        expect(audit.descriptions.first, 'Generó reporte: Reporte ficticio');
        expect(n.state.generating, isFalse);
        expect(n.state.warning, isNull);
        final restarted = notifier(memory, sources, actor: actor);
        addTearDown(restarted.dispose);
        await restarted.load();
        expect(restarted.state.reports.single.toJson(), created.toJson());
        expect(memory.writes, 1);
      },
    );
  }
  test(
    'Hasta hoy incluye signos y eventos del último segundo, sin incluir mañana',
    () async {
      final memory = MemoryReports(), sources = Sources();
      final start = DateTime(2026, 10, 4),
          end = DateTime(2026, 10, 4, 23, 59, 59, 999, 999);
      sources.vitals = [
        vital(date: start),
        vital(id: '9', date: end),
        vital(id: '10', date: start.subtract(const Duration(microseconds: 1))),
        vital(id: '11', date: end.add(const Duration(microseconds: 1))),
      ];
      sources.audits = [
        for (final entry in [
          ('1', start),
          ('2', end),
          ('3', end.add(const Duration(microseconds: 1))),
        ])
          AuditLog(
            id: entry.$1,
            entityType: 'CLINICAL_EVENT',
            entityId: '1',
            actionType: 'CREATE',
            performedBy: doctor.username,
            performedAt: entry.$2,
          ),
      ];
      final n = notifier(memory, sources);
      addTearDown(n.dispose);
      final result = await generate(n, from: start, to: start);
      expect(result.summary!.vitalSigns, 2);
      expect(result.summary!.clinicalEvents, 2);
      expect(result.summary!.auditLogs, 2);
      expect(sources.calls, isNot(contains('clinical-events')));
    },
  );
  test('alertas filtran fecha real; fecha ausente cuenta; CLOSED nunca activa/crítica', () async {
    final sources = Sources()
      ..alerts = [
        notification.alert(id: '1'),
        notification.alert(id: '2', severity: 'HIGH', status: 'ATTENDED'),
        notification.alert(id: '3', date: null),
        notification.alert(id: '4', status: 'CLOSED'),
        notification.alert(id: '5', date: '2026-10-03T23:59:59'),
        notification.alert(id: '6', date: '2026-10-05T00:00:00'),
      ];
    final n = notifier(MemoryReports(), sources);
    addTearDown(n.dispose);
    final result = await generate(n);
    expect(result.summary!.activeAlerts, 3);
    expect(result.summary!.criticalAlerts, 2);
    expect(result.clinicalConclusion, contains('2 alerta(s) crítica(s)'));
  });
  test('SBAR agrega por paciente y admite fecha ausente como la web', () async {
    final sources = Sources()..patients = [patient(), patient(id: '2')];
    sources.transfers = {
      '1': [
        sbar.transfer(),
        sbar.transfer(id: '10', date: null),
        sbar.transfer(id: '11', date: '2026-10-03T12:00:00'),
      ],
      '2': [sbar.transfer(id: '12', patientId: '2')],
    };
    final n = notifier(MemoryReports(), sources);
    addTearDown(n.dispose);
    final result = await generate(n);
    expect(result.summary!.sbarTransfers, 3);
    expect(result.summary!.patients, 2);
    expect(sources.calls, containsAll(['sbar/1', 'sbar/2']));
  });
  for (final resource in ['vitals', 'alerts', 'audits', 'sbar/1']) {
    test(
      'fallo parcial de $resource genera con cero solo en esa parte',
      () async {
        final memory = MemoryReports(), sources = Sources();
        sources.vitals = [vital()];
        sources.alerts = [notification.alert()];
        sources.transfers = {
          '1': [sbar.transfer()],
        };
        sources.audits = [
          AuditLog(
            id: '1',
            entityType: 'CLINICAL_EVENT',
            entityId: '1',
            actionType: 'CREATE',
            performedBy: doctor.username,
            performedAt: now,
          ),
        ];
        sources.failures[resource] = StateError('Error simulado');
        final n = notifier(memory, sources);
        addTearDown(n.dispose);
        final result = await generate(n);
        expect(result.summary!.vitalSigns, resource == 'vitals' ? 0 : 1);
        expect(result.summary!.activeAlerts, resource == 'alerts' ? 0 : 1);
        expect(result.summary!.sbarTransfers, resource == 'sbar/1' ? 0 : 1);
        expect(result.summary!.clinicalEvents, resource == 'audits' ? 0 : 1);
        expect(result.summary!.auditLogs, resource == 'audits' ? 0 : 1);
        expect(memory.writes, 1);
      },
    );
  }
  test(
    'fallo de un paciente en SBAR conserva los traspasos de los otros',
    () async {
      final sources = Sources()
        ..patients = [patient(), patient(id: '2')]
        ..transfers = {
          '2': [sbar.transfer(patientId: '2')],
        };
      sources.failures['sbar/1'] = StateError('Error simulado');
      final n = notifier(MemoryReports(), sources);
      addTearDown(n.dispose);
      expect((await generate(n)).summary!.sbarTransfers, 1);
    },
  );
  test('pacientes falla: error, cero guardados y cero auditorías; conserva anterior', () async {
    final memory = MemoryReports();
    await memory.store.add(report());
    final sources = Sources()
      ..failures['patients'] = StateError('Error simulado');
    final audit = AuditCalls();
    final n = notifier(memory, sources, audit: audit);
    addTearDown(n.dispose);
    await n.load();
    await expectLater(generate(n), throwsStateError);
    expect(n.state.error, isNotNull);
    expect(n.state.reports, hasLength(1));
    expect(sources.calls, ['patients']);
    expect(memory.writes, 1);
    expect(audit.actions, isEmpty);
    sources.failures.clear();
    await generate(n);
    expect(n.state.reports, hasLength(2));
    expect(n.state.error, isNull);
  });
  test(
    'pacientes vacío genera resumen cero sin consultar SBAR global inventado',
    () async {
      final sources = Sources()..patients = [];
      final n = notifier(MemoryReports(), sources);
      addTearDown(n.dispose);
      final result = await generate(n);
      expect(result.summary!.patients, 0);
      expect(result.summary!.sbarTransfers, 0);
      expect(sources.calls.where((path) => path.startsWith('sbar')), isEmpty);
    },
  );
  test('fallo de guardado no publica éxito ni envía auditoría', () async {
    final memory = MemoryReports()
      ..writeFailure = StateError('Sin espacio simulado');
    final audit = AuditCalls();
    final n = notifier(memory, Sources(), audit: audit);
    addTearDown(n.dispose);
    await expectLater(generate(n), throwsFormatException);
    expect(n.state.reports, isEmpty);
    expect(memory.raw, isNull);
    expect(audit.actions, isEmpty);
    memory.writeFailure = null;
    await generate(n);
    expect(n.state.reports, hasLength(1));
  });
  test('auditoría falla: reporte sigue guardado y refrescar no repite generación ni auditorías', () async {
    final memory = MemoryReports(), sources = Sources();
    final audit = AuditCalls()..failure = StateError('Error simulado');
    var refreshed = 0;
    final n = notifier(
      memory,
      sources,
      audit: audit,
      onAudited: () {
        refreshed++;
      },
    );
    addTearDown(n.dispose);
    final result = await generate(n);
    expect(n.state.warning, contains('Reporte guardado'));
    expect((await memory.store.getAll()).single.id, result.id);
    await n.load();
    expect(memory.writes, 1);
    expect(audit.actions, ['VIEW', 'UPDATE']);
    expect(refreshed, 1);
  });
  test('fallo de invalidación no revierte un reporte confirmado', () async {
    final n = notifier(
      MemoryReports(),
      Sources(),
      onAudited: () => throw StateError('Error simulado'),
    );
    addTearDown(n.dispose);
    await generate(n);
    expect(n.state.reports, hasLength(1));
  });
  test(
    'doble envío y refresco durante generación producen un solo guardado',
    () async {
      final sources = Sources()..patientGate = Completer<List<Patient>>();
      final memory = MemoryReports();
      final n = notifier(memory, sources);
      addTearDown(n.dispose);
      final pending = generate(n);
      await expectLater(generate(n), throwsFormatException);
      await n.load();
      expect(memory.reads, 0);
      sources.patientGate!.complete([patient()]);
      await pending;
      expect(memory.writes, 1);
      expect(sources.calls.where((path) => path == 'patients'), hasLength(1));
    },
  );
  test(
    'doble envío también se bloquea durante guardado y auditoría posterior',
    () async {
      final memory = MemoryReports()..writing = Completer<void>();
      final audit = AuditCalls()..gate = Completer<void>();
      final n = notifier(memory, Sources(), audit: audit);
      addTearDown(n.dispose);
      final pending = generate(n);
      await Future<void>.delayed(Duration.zero);
      expect(n.state.generating, isTrue);
      await expectLater(generate(n), throwsFormatException);
      memory.writing!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(n.state.reports, hasLength(1));
      await expectLater(generate(n), throwsFormatException);
      audit.gate!.complete();
      await pending;
      expect(memory.writes, 1);
    },
  );
  test(
    'cargas simultáneas comparten lectura; generación espera a que termine',
    () async {
      final memory = MemoryReports()..reading = Completer<String?>();
      final sources = Sources();
      final n = notifier(memory, sources);
      addTearDown(n.dispose);
      final first = n.load(), second = n.load();
      expect(memory.reads, 1);
      await expectLater(generate(n), throwsFormatException);
      expect(sources.calls, isEmpty);
      memory.reading!.complete(null);
      await Future.wait([first, second]);
      expect(n.state.loading, isFalse);
    },
  );
  test('lectura local falla: conserva listado y permite reintento', () async {
    final memory = MemoryReports();
    await memory.store.add(report());
    final n = notifier(memory, Sources());
    addTearDown(n.dispose);
    await n.load();
    memory.readFailure = StateError('Error simulado');
    await n.load();
    expect(n.state.reports, hasLength(1));
    expect(n.state.error, isNotNull);
    memory.readFailure = null;
    await n.load();
    expect(n.state.error, isNull);
  });
  test(
    'cambio de sesión antes de guardar bloquea persistencia y efectos',
    () async {
      User? actor = doctor;
      final sources = Sources()..patientGate = Completer<List<Patient>>();
      final memory = MemoryReports();
      final audit = AuditCalls();
      final n = notifier(memory, sources, user: () => actor, audit: audit);
      addTearDown(n.dispose);
      final pending = generate(n);
      actor = nurse;
      sources.patientGate!.complete([patient()]);
      await expectLater(pending, throwsFormatException);
      expect(memory.writes, 0);
      expect(audit.actions, isEmpty);
      expect(n.state.reports, isEmpty);
    },
  );
  test('sesión cambia después de guardar: no publica ni audita a nombre del nuevo usuario', () async {
    User? actor = doctor;
    final memory = MemoryReports()..writing = Completer<void>();
    final audit = AuditCalls();
    final n = notifier(memory, Sources(), user: () => actor, audit: audit);
    addTearDown(n.dispose);
    final pending = generate(n);
    await Future<void>.delayed(Duration.zero);
    actor = nurse;
    memory.writing!.complete();
    await pending;
    expect(memory.raw, isNotNull);
    expect(n.state.reports, isEmpty);
    expect(audit.actions, isEmpty);
  });
  test(
    'notifier descartado no guarda una generación que aún está leyendo',
    () async {
      final sources = Sources()..patientGate = Completer<List<Patient>>();
      final memory = MemoryReports();
      final n = notifier(memory, sources);
      final pending = generate(n);
      n.dispose();
      sources.patientGate!.complete([patient()]);
      await expectLater(pending, throwsFormatException);
      expect(memory.writes, 0);
    },
  );
}
