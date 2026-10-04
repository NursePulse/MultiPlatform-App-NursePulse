import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/clinical_event/domain/clinical_event.dart';
import 'package:nurse_pulse_app/features/clinical_event/domain/clinical_event_rules.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';

import 'fixtures.dart';

void main() {
  for (final spec in [('Título', 4, 120), ('Descripción', 10, 1000)]) {
    final (label, min, max) = spec;
    for (final size in [min - 1, min, max, max + 1]) {
      test('$label: límite $size tras trim', () {
        expect(
          ClinicalEventRules.text(' ${'x' * size} ', label, min, max),
          size < min || size > max ? isNotNull : isNull,
        );
      });
    }
    for (final value in [null, '', '   ', '\n\t']) {
      test('$label: obligatorio para $value', () {
        expect(ClinicalEventRules.text(value, label, min, max), isNotNull);
      });
    }
  }
  for (final id in [
    '',
    ' ',
    '0',
    '-1',
    '1.5',
    'abc',
    '+1',
    '9999999999999999999999',
  ]) {
    test('rechaza ID $id', () {
      expect(
        () => ClinicalEventRules.validate(command(patientId: id)),
        throwsFormatException,
      );
    });
  }
  test('normaliza espacios, ID y payload sin autor ni fecha inventados', () {
    final c = ClinicalEventRules.validate(command(patientId: ' 001 '));
    expect(c.toJson(), {
      'patientId': 1,
      'eventType': 'OBSERVATION',
      'severity': 'LOW',
      'title': 'Control',
      'description': 'Observación ficticia',
    });
  });
  test('tipos y severidades usan exclusivamente valores del dominio', () {
    for (final type in ClinicalEventType.values) {
      for (final severity in ClinicalEventSeverity.values) {
        expect(
          () => ClinicalEventRules.validate(
            command(type: type, severity: severity),
          ),
          returnsNormally,
        );
      }
    }
    for (final bad in ['', ' ', 'observacion', 'Otro']) {
      expect(
        () => ClinicalEventRules.validate(command(type: bad)),
        throwsFormatException,
      );
      expect(
        () => ClinicalEventRules.validate(command(severity: bad)),
        throwsFormatException,
      );
    }
  });
  test('permisos Nurse/Doctor/Admin y ningún fallback para desconocidos', () {
    for (final role in [kRoleNurse, kRoleDoctor, kRoleAdmin]) {
      expect(ClinicalEventRules.canRegister([role]), isTrue);
    }
    for (final roles in [
      <String>[],
      ['UNKNOWN'],
      ['Nurse'],
    ]) {
      expect(ClinicalEventRules.canRegister(roles), isFalse);
    }
  });
  test('solo HIGH/CRITICAL requieren alerta', () {
    for (final severity in ClinicalEventSeverity.values) {
      expect(
        ClinicalEventRules.needsAlert(eventFrom(command(severity: severity))),
        ['HIGH', 'CRITICAL'].contains(severity),
      );
    }
  });
  test('alerta respeta 255 sin truncar el evento original', () {
    final event = eventFrom(
      command(title: 'T' * 120, description: 'D' * 1000, severity: 'CRITICAL'),
    );
    final summary = ClinicalEventRules.alertDescription(event);
    expect(summary.length, lessThanOrEqualTo(255));
    expect(summary, startsWith('Evento clínico crítico: OBSERVATION:'));
    expect(summary, endsWith('…'));
    expect(event.description.length, 1000);
    expect(
      ClinicalEventRules.alertDescription(eventFrom(command())),
      contains('Observación ficticia'),
    );
  });
  test('resumen no corta un emoji en el límite UTF-16', () {
    final prefix = 'Evento clínico de alto riesgo: OBSERVATION: TTTT. ';
    final description = '${'x' * (253 - prefix.length)}😀fin';
    final summary = ClinicalEventRules.alertDescription(
      eventFrom(
        command(title: 'TTTT', description: description, severity: 'HIGH'),
      ),
    );
    expect(summary, endsWith('x…'));
    expect(summary.contains('\uD83D'), isFalse);
  });
}
