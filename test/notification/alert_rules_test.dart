import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/notification/domain/alert.dart';
import 'package:nurse_pulse_app/features/notification/domain/alert_rules.dart';

import 'fixtures.dart';

void main() {
  for (final value in [null, '', ' ', '\n\t']) {
    test('descripción vacía $value rechazada', () {
      expect(AlertRules.description(value), isNotNull);
    });
  }
  for (final length in [1, 254, 255]) {
    test('descripción trim de $length caracteres válida', () {
      expect(AlertRules.description(' ${'x' * length} \n'), isNull);
    });
  }
  test('256 caracteres se rechazan sin truncar', () {
    expect(AlertRules.description('x' * 256), isNotNull);
  });
  for (final id in [null, '', ' ', '-1', '0', '1.5', 'abc', '+1', '1e2']) {
    test('ID inválido $id', () {
      expect(AlertRules.id(id, 'un paciente'), isNotNull);
    });
  }
  test('ID positivo y espacios aceptados', () {
    expect(AlertRules.id(' 001 ', 'un paciente'), isNull);
  });
  for (final staff in [nurse, doctor, admin]) {
    test('${staff.username} lee, crea y atiende', () {
      expect(AlertRules.canManage(staff.roles), isTrue);
      expect(AlertRules.canClose(staff.roles), staff != nurse);
    });
  }
  test('roles desconocidos no gestionan ni cierran', () {
    expect(AlertRules.canManage(['NURSE']), isFalse);
    expect(AlertRules.canClose([]), isFalse);
  });
  for (final type in AlertType.values) {
    test('tipo $type válido', () {
      expect(() => AlertRules.validateCreate('1', type, 'x'), returnsNormally);
    });
  }
  test('tipo desconocido rechazado', () {
    expect(
      () => AlertRules.validateCreate('1', 'UNKNOWN', 'x'),
      throwsFormatException,
    );
  });
  for (final length in [0, 121]) {
    test('actor de $length caracteres rechazado', () {
      expect(() => AlertRules.actor('x' * length), throwsFormatException);
    });
  }
  test('actor trim y límite 120', () {
    expect(AlertRules.actor(' ${'x' * 120} '), 'x' * 120);
  });
  for (final text in ['', ' ', 'x' * 256]) {
    test('notas inválidas longitud ${text.length}', () {
      expect(() => AlertRules.notes(text), throwsFormatException);
    });
  }
  test('notas trim y límite 255', () {
    expect(AlertRules.notes(' ${'x' * 255} '), 'x' * 255);
  });
  test('cada gravedad filtra exactamente y excluye cerradas', () {
    final alerts = [
      alert(id: '1'),
      alert(id: '2', severity: 'HIGH'),
      alert(id: '3', severity: 'MEDIUM'),
      alert(id: '4', severity: 'LOW'),
      alert(id: '5', status: 'ATTENDED'),
      alert(id: '6', status: 'CLOSED'),
    ];
    expect(AlertRules.filter(alerts, AlertFilter.all).map((a) => a.id), [
      '1',
      '2',
      '3',
      '4',
      '5',
    ]);
    expect(AlertRules.filter(alerts, AlertFilter.critical).map((a) => a.id), [
      '1',
      '5',
    ]);
    expect(AlertRules.filter(alerts, AlertFilter.moderate).map((a) => a.id), [
      '3',
    ]);
    expect(AlertRules.filter(alerts, AlertFilter.high).map((a) => a.id), ['2']);
    expect(AlertRules.filter(alerts, AlertFilter.low).map((a) => a.id), ['4']);
  });
  test('fecha ausente no se inventa ni se sustituye por atención/cierre', () {
    final json = alertJson(
      date: null,
      attendedBy: nurse.username,
      closedBy: doctor.username,
    );
    expect(Alert.fromJson(json).triggeredAt, isNull);
    json['triggeredAt'] = 'fecha inválida';
    expect(Alert.fromJson(json).triggeredAt, isNull);
    expect(Alert.fromJson(json).attendedAt, isNotNull);
  });
  test('fecha proviene de la API', () {
    expect(alert().triggeredAt, DateTime(2026, 10, 4, 12));
  });
  for (final field in ['status', 'severity', 'id', 'patientId']) {
    test('respuesta con $field desconocido no fabrica estado o IDs', () {
      final json = alertJson()..[field] = 'UNKNOWN';
      expect(() => Alert.fromJson(json), throwsFormatException);
    });
  }
}
