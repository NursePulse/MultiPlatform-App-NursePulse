import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/sbar/domain/sbar_rules.dart';
import 'package:nurse_pulse_app/features/sbar/domain/sbar_transfer.dart';

import 'fixtures.dart';

void main() {
  for (final label in [
    'Situación',
    'Antecedentes',
    'Evaluación',
    'Recomendación',
  ]) {
    for (final size in [7, 8, 1000, 1001]) {
      test('$label: límite $size tras trim', () {
        expect(
          SbarRules.section(' ${'x' * size} ', label),
          size == 7 || size == 1001 ? isNotNull : isNull,
        );
      });
    }
    for (final value in [null, '', ' \n\t ']) {
      test('$label obligatorio: $value', () {
        expect(SbarRules.section(value, label), isNotNull);
      });
    }
  }
  for (final value in [
    '',
    ' ',
    '0',
    '-1',
    '1.2',
    'abc',
    '+1',
    '9999999999999999999999',
  ]) {
    test('paciente y receptor rechazan ID $value', () {
      expect(
        () => SbarRules.validate(command(patientId: value), actorId: '2'),
        throwsFormatException,
      );
      expect(
        () => SbarRules.validate(command(target: value), actorId: '2'),
        throwsFormatException,
      );
    });
  }
  test(
    'receptor obligatorio y distinto del actor, aun con ceros iniciales',
    () {
      for (final target in [null, '2', ' 002 ']) {
        expect(
          () => SbarRules.validate(command(target: target), actorId: '2'),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'normaliza los cuatro campos y IDs sin incluir identidades del cliente',
    () {
      final validated = SbarRules.validate(
        command(patientId: ' 001 ', target: ' 003 '),
        actorId: '2',
      );
      expect(validated.toJson(), {
        'patientId': 1,
        'targetNurseId': 3,
        'title': 'SBAR ficticio',
        'situation': 'Situación ficticia',
        'background': 'Antecedentes ficticios',
        'assessment': 'Evaluación ficticia',
        'recommendation': 'Recomendación ficticia',
      });
    },
  );
  test('validación de comandos directos para los cuatro campos', () {
    for (final value in [' ', 'x' * 7, 'x' * 1001]) {
      for (final c in [
        command(situation: value),
        command(background: value),
        command(assessment: value),
        command(recommendation: value),
      ]) {
        expect(
          () => SbarRules.validate(c, actorId: '2'),
          throwsFormatException,
        );
      }
    }
    expect(
      () => SbarRules.validate(
        command(
          situation: 'x' * 8,
          background: 'x' * 1000,
          assessment: 'x' * 8,
          recommendation: 'x' * 1000,
        ),
        actorId: '2',
      ),
      returnsNormally,
    );
  });
  test('título compatible con límite 255 del contrato', () {
    for (final title in ['', ' ', 'x' * 256]) {
      expect(
        () => SbarRules.validate(command(title: title), actorId: '2'),
        throwsFormatException,
      );
    }
    for (final title in ['x', 'x' * 255]) {
      expect(
        () => SbarRules.validate(command(title: title), actorId: '2'),
        returnsNormally,
      );
    }
  });
  test('permisos: Nurse/Admin gestionan; Doctor solo consulta', () {
    for (final role in [kRoleNurse, kRoleDoctor, kRoleAdmin]) {
      expect(SbarRules.canRead([role]), isTrue);
      expect(SbarRules.canManage([role]), role != kRoleDoctor);
    }
    expect(SbarRules.canRead([]), isFalse);
    expect(SbarRules.canManage(['UNKNOWN']), isFalse);
  });
  test('directorio conserva únicamente otros Nurse y ordena por usuario', () {
    expect(
      SbarRules.receivers([
        actor,
        receiver,
        const User(id: '4', username: 'doctor.test', roles: [kRoleDoctor]),
        const User(id: '5', username: 'admin.test', roles: [kRoleAdmin]),
        const User(id: 'invalid', username: 'invalid', roles: [kRoleNurse]),
      ], actor.id).map((u) => u.id),
      ['3'],
    );
  });
  test('estado desconocido o ausente no se presenta como PENDING', () {
    expect(transfer(status: 'UNKNOWN').statusLabel, 'UNKNOWN');
    final json = transferJson()..remove('status');
    expect(() => SbarTransfer.fromJson(json), throwsA(isA<TypeError>()));
    expect(transfer(status: 'ACKNOWLEDGED').canAcknowledge, isFalse);
  });
}
