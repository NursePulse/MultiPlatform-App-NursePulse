import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/patient/domain/patient_monitoring_rules.dart';
import 'package:nurse_pulse_app/features/patient/domain/patient_rules.dart';

import 'fixtures.dart';

void main() {
  for (final id in ['', ' ', '0', '-1', '+1', '1.5', 'abc', '1e2']) {
    test('ID inválido $id rechazado', () {
      expect(() => PatientMonitoringRules.id(id), throwsFormatException);
    });
  }
  test('ID positivo trim y ceros normalizados', () {
    expect(PatientMonitoringRules.id(' 007 '), '7');
  });
  for (final staff in [nurse, doctor, admin]) {
    test('${staff.username} consulta seguimiento', () {
      expect(PatientMonitoringRules.canRead(staff.roles), isTrue);
    });
  }
  test('rol desconocido no consulta', () {
    expect(PatientMonitoringRules.canRead([]), isFalse);
  });
  for (final period in [
    (null, now),
    (now, null),
    (now, DateTime(2026, 10, 3)),
    (DateTime(1929, 12, 31), now),
    (now, DateTime(2026, 10, 5)),
  ]) {
    test('periodo inválido $period', () {
      expect(
        PatientMonitoringRules.period(period.$1, period.$2, today: now),
        isNotNull,
      );
    });
  }
  test('sin periodo y extremos 1930/hoy válidos', () {
    expect(PatientMonitoringRules.period(null, null, today: now), isNull);
    expect(
      PatientMonitoringRules.period(DateTime(1930), now, today: now),
      isNull,
    );
    expect(PatientMonitoringRules.period(now, now, today: now), isNull);
  });
  test('periodo incluye ambos días completos y convierte UTC a local', () {
    final start = DateTime(2026, 10, 1), end = DateTime(2026, 10, 4);
    for (final date in [
      start,
      DateTime(2026, 10, 4, 23, 59, 59),
      start.toUtc(),
    ]) {
      expect(PatientRules.inPeriod(date, from: start, to: end), isTrue);
    }
    expect(
      PatientRules.inPeriod(
        DateTime(2026, 9, 30, 23, 59, 59),
        from: start,
        to: end,
      ),
      isFalse,
    );
    expect(
      PatientRules.inPeriod(DateTime(2026, 10, 5), from: start, to: end),
      isFalse,
    );
  });
}
