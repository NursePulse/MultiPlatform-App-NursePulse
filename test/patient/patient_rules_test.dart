import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/patient/domain/patient_rules.dart';

import 'fixtures.dart';

void main() {
  test('nombres: letras españolas, espacios, vacío y límite 80', () {
    expect(PatientRules.name(' María José Ñúñez ', 'Nombre'), isNull);
    expect(PatientRules.name('A' * 80, 'Nombre'), isNull);

    for (final value in ['', '   ', 'Ana2', '<Ana>', 'A' * 81]) {
      expect(PatientRules.name(value, 'Nombre'), isNotNull);
    }
  });

  test('documento: 8–20 dígitos y preserva ceros iniciales', () {
    for (final value in ['00123456', '1' * 20]) {
      expect(PatientRules.document(value), isNull);
    }

    for (final value in ['', '1' * 7, '1' * 21, '1234567A', '1234 5678']) {
      expect(PatientRules.document(value), isNotNull);
    }

    final c = PatientRules.validate(patientCommand());
    expect(c.documentNumber, '00123456');
    expect(c.firstName, 'Ana');
    expect(c.toJson()['birthDate'], '2000-02-15');
  });

  test('fechas: 1930 y hoy incluidos; futuro y nulo rechazados', () {
    final today = DateTime(2026, 10, 4);

    expect(PatientRules.birth(DateTime(1930), today: today), isNull);
    expect(PatientRules.birth(today, today: today), isNull);
    expect(PatientRules.birth(DateTime(1929, 12, 31), today: today), isNotNull);
    expect(PatientRules.birth(DateTime(2026, 10, 5), today: today), isNotNull);
    expect(PatientRules.birth(null), isNotNull);
    expect(PatientRules.admission(today, today: today), isNull);
    expect(
      PatientRules.admission(DateTime(2026, 10, 5), today: today),
      isNotNull,
    );
  });

  test('no aplica la edad del personal a pacientes menores de edad', () {
    expect(
      () => PatientRules.validate(patientCommand(birth: DateTime(2025))),
      returnsNormally,
    );
  });

  test(
    'longitudes y género: valida también comandos construidos sin formulario',
    () {
      expect(PatientRules.text('x' * 180, 'Diagnóstico', 180), isNull);
      expect(PatientRules.text('x' * 181, 'Diagnóstico', 180), isNotNull);
      expect(PatientRules.text('x' * 20, 'Habitación', 20), isNull);
      expect(PatientRules.text('x' * 21, 'Habitación', 20), isNotNull);
      expect(PatientRules.text('x' * 120, 'Médico', 120), isNull);
      expect(PatientRules.text('x' * 121, 'Médico', 120), isNotNull);
      expect(
        () => PatientRules.validate(patientCommand(gender: 'invalid')),
        throwsFormatException,
      );
      expect(
        () => PatientRules.validate(patientCommand(document: 'abc')),
        throwsFormatException,
      );
    },
  );

  test('duplicado excluye el paciente que se está editando', () {
    final patient = patientFrom(patientCommand());

    expect(PatientRules.duplicate([patient], '00123456'), isTrue);
    expect(
      PatientRules.duplicate([patient], '00123456', excludingId: '1'),
      isFalse,
    );
    expect(PatientRules.matches(patient, '  LÓPEZ  '), isTrue);
    expect(PatientRules.matches(patient, '00123456'), isTrue);
    expect(PatientRules.matches(patient, 'inexistente'), isFalse);
  });

  test(
    'periodo incluye todo el último día y excluye medianoche del siguiente',
    () {
      final start = DateTime(2026, 10, 3);
      final end = DateTime(2026, 10, 4);

      expect(PatientRules.inPeriod(start, from: start, to: end), isTrue);
      expect(
        PatientRules.inPeriod(
          DateTime(2026, 10, 4, 23, 59, 59),
          from: start,
          to: end,
        ),
        isTrue,
      );
      expect(
        PatientRules.inPeriod(DateTime(2026, 10, 5), from: start, to: end),
        isFalse,
      );
      expect(
        PatientRules.inPeriod(DateTime(2026, 10, 2), from: start, to: end),
        isFalse,
      );
    },
  );

  test(
    'permisos clínicos: crear Nurse/Admin, editar clínicos, eliminar Admin',
    () {
      final doctor = PatientPermissions([kRoleDoctor]);
      final nurse = PatientPermissions([kRoleNurse]);

      expect(doctor.create, isFalse);
      expect(doctor.update, isTrue);
      expect(doctor.delete, isFalse);
      expect(nurse.create, isTrue);
      expect(nurse.update, isTrue);
      expect(nurse.delete, isFalse);
      expect(const PatientPermissions([kRoleAdmin]).delete, isTrue);
      expect(const PatientPermissions(['UNKNOWN']).update, isFalse);
    },
  );

  test('médico muestra nombre completo o usuario si faltan nombres', () {
    expect(
      User.fromJson({
        'id': 1,
        'username': 'doctor',
        'roles': [kRoleDoctor],
        'firstName': 'Luis',
        'lastName': 'Soto',
      }).displayName,
      'Luis Soto',
    );

    expect(
      const User(id: '1', username: 'doctor', roles: []).displayName,
      'doctor',
    );
  });
}
