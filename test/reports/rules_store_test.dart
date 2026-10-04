import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/report/domain/report.dart';
import 'package:nurse_pulse_app/features/report/domain/report_rules.dart';
import 'package:nurse_pulse_app/features/report/infrastructure/report_local_store.dart';

import 'fixtures.dart';

void main() {
  for (final actor in [
    null,
    nurse,
    const User(id: '7', username: 'unknown.test', roles: ['UNKNOWN']),
  ]) {
    test(
      'Reportes rechaza ${actor?.primaryRole}',
      () => expect(ReportRules.canGenerate(actor), isFalse),
    );
  }
  for (final actor in [doctor, admin]) {
    test(
      'Reportes permite ${actor.primaryRole}',
      () => expect(ReportRules.canGenerate(actor), isTrue),
    );
  }
  for (final text in ['', ' ', '\n\t']) {
    test(
      'título vacío ${text.length}',
      () => expect(
        () => ReportRules.validate(ReportType.general, text, now, now),
        throwsFormatException,
      ),
    );
  }
  test('fecha inicial y final son obligatorias', () {
    expect(
      () => ReportRules.validate(ReportType.general, 'Reporte', null, now),
      throwsFormatException,
    );
    expect(
      () => ReportRules.validate(ReportType.general, 'Reporte', now, null),
      throwsFormatException,
    );
  });
  test('rango invertido y tipo inexistente son inválidos', () {
    expect(
      () => ReportRules.validate(
        ReportType.general,
        'Reporte',
        now.add(const Duration(days: 1)),
        now,
      ),
      throwsFormatException,
    );
    expect(
      () => ReportRules.validate('UNKNOWN', 'Reporte', now, now),
      throwsFormatException,
    );
  });
  test('mismo día admite orden de horas inverso y normaliza días locales', () {
    final period = ReportRules.validate(
      ReportType.general,
      ' Reporte ',
      DateTime(2026, 10, 4, 23),
      DateTime(2026, 10, 4),
    );
    expect(period.start, DateTime(2026, 10, 4));
    expect(period.end, DateTime(2026, 10, 4, 23, 59, 59, 999, 999));
    expect(period.contains(period.start), isTrue);
    expect(period.contains(period.end), isTrue);
    expect(
      period.contains(period.start.subtract(const Duration(microseconds: 1))),
      isFalse,
    );
    expect(
      period.contains(period.end.add(const Duration(microseconds: 1))),
      isFalse,
    );
    expect(period.contains(period.end.toUtc()), isTrue);
  });
  test('fin de mes, año y día bisiesto incluyen el día completo', () {
    for (final date in [
      DateTime(2026, 12, 31),
      DateTime(2024, 2, 29),
      DateTime(2026, 4, 30),
    ]) {
      final period = ReportRules.validate(
        ReportType.general,
        'Reporte',
        date,
        date,
      );
      expect(period.end.day, date.day);
      expect(period.end.hour, 23);
      expect(period.contains(period.end), isTrue);
    }
  });
  for (final entry in [
    (
      summary(alerts: 3, critical: 2),
      'Se detectaron 2 alerta(s) crítica(s). Requiere revisión médica prioritaria.',
    ),
    (
      summary(alerts: 3),
      'Existen 3 alerta(s) activa(s). Mantener seguimiento del turno.',
    ),
    (
      summary(vitals: 1),
      'Periodo con actividad clínica registrada y sin alertas críticas activas.',
    ),
    (
      summary(sbar: 1),
      'Periodo con actividad clínica registrada y sin alertas críticas activas.',
    ),
    (
      summary(events: 1, audit: 1),
      'No se encontraron movimientos clínicos relevantes en el periodo seleccionado.',
    ),
  ]) {
    test(
      'conclusión coincide con la web: ${entry.$2}',
      () => expect(ReportRules.conclusion(entry.$1), entry.$2),
    );
  }
  test('actividad total y tono del detalle coinciden con la web', () {
    expect(
      summary(
        patients: 99,
        vitals: 2,
        events: 3,
        sbar: 4,
        alerts: 5,
        critical: 2,
        audit: 6,
      ).activityTotal,
      20,
    );
    expect(ReportRules.tone(summary(critical: 1)), 'Prioridad crítica');
    expect(ReportRules.tone(summary(alerts: 1)), 'Requiere seguimiento');
  });
  test('persistencia entre instancias conserva ID, fechas y resumen sin llamadas HTTP', () async {
    final memory = MemoryReports();
    final original = report();
    await memory.store.add(original);
    final restored = (await memory.store.getAll()).single;
    expect(restored.toJson(), original.toJson());
    expect(memory.writes, 1);
  });
  test(
    'conserva reportes previos y ordena por creación; un ID se guarda una vez',
    () async {
      final memory = MemoryReports();
      await memory.store.add(report(id: '1', date: now));
      await memory.store.add(
        report(id: '2', date: now.add(const Duration(days: 1))),
      );
      await memory.store.add(report(id: '1', date: now));
      expect((await memory.store.getAll()).map((r) => r.id), ['2', '1']);
    },
  );
  for (final raw in [
    null,
    '',
    '{not json',
    '{}',
    'null',
    '[null]',
    '[{}]',
    '[1]',
    '["texto"]',
    '[{"title":"ficticio"}]',
  ]) {
    test(
      'almacenamiento vacío o corrupto ${raw ?? 'ausente'} no derriba lista',
      () async {
        final memory = MemoryReports()..raw = raw;
        expect(await memory.store.getAll(), isEmpty);
        expect(memory.writes, 0);
      },
    );
  }
  for (final field in [
    'id',
    'title',
    'startDate',
    'endDate',
    'type',
    'status',
    'summary',
  ]) {
    test(
      'esquema local corrupto en $field se recupera con lista vacía',
      () async {
        final json = report().toJson();
        json[field] = null;
        final memory = MemoryReports()..raw = jsonEncode([json]);
        expect(await memory.store.getAll(), isEmpty);
      },
    );
  }
  test('resumen negativo y IDs duplicados son corrupción', () async {
    final json = report().toJson();
    json['summary'] = {...summary().toJson(), 'patients': -1};
    final memory = MemoryReports()..raw = jsonEncode([json]);
    expect(await memory.store.getAll(), isEmpty);
    memory.raw = jsonEncode([report().toJson(), report().toJson()]);
    expect(await memory.store.getAll(), isEmpty);
  });
  test(
    'falla de almacenamiento no se presenta como corrupción o guardado exitoso',
    () async {
      final memory = MemoryReports()
        ..readFailure = StateError('Lectura simulada');
      await expectLater(memory.store.getAll(), throwsStateError);
      await expectLater(memory.store.add(report()), throwsStateError);
      expect(memory.writes, 0);
      memory.readFailure = null;
      memory.writeFailure = StateError('Guardado simulado');
      await expectLater(memory.store.add(report()), throwsStateError);
      expect(memory.raw, isNull);
    },
  );
  test(
    'IDs locales UUID independientes y compatibles con entityId de auditoría',
    () {
      final ids = List.generate(100, (_) => newReportId());
      expect(ids.toSet(), hasLength(100));
      expect(
        ids.every(
          (id) => RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ).hasMatch(id),
        ),
        isTrue,
      );
    },
  );
}
