import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/audit/domain/audit_log.dart';
import 'package:nurse_pulse_app/features/audit/domain/audit_rules.dart';
import 'package:nurse_pulse_app/features/iam/domain/user_management_rules.dart';

import 'fixtures.dart';

void main() {
  test('permisos reales de auditoría y administración', () {
    expect([nurse, doctor, admin].map(AuditRules.canRead), [false, true, true]);
    expect([nurse, doctor, admin].map(UserManagementRules.canManage), [
      false,
      false,
      true,
    ]);
    expect(AuditRules.canRead(null), isFalse);
    expect(UserManagementRules.canManage(null), isFalse);
  });
  for (final id in [
    '',
    ' ',
    '0',
    '-1',
    '+1',
    '1.2',
    '1e2',
    'abc',
    '999999999999999999999',
  ]) {
    test('IDs inválidos "$id" rechazados por ambas reglas', () {
      expect(() => AuditRules.id(id), throwsFormatException);
      expect(() => UserManagementRules.id(id), throwsFormatException);
    });
  }
  test('normaliza enteros positivos con espacios y ceros iniciales', () {
    expect(AuditRules.id(' 001 '), '1');
    expect(UserManagementRules.id(' 001 '), '1');
  });
  for (final roles in [
    <String>[],
    [''],
    [' '],
    ['ROLE_UNKNOWN'],
    ['ROLE_NURSE', 'ROLE_DOCTOR'],
    ['ROLE_NURSE', 'ROLE_NURSE'],
    ['role_nurse'],
  ]) {
    test(
      'rol inválido $roles',
      () =>
          expect(() => UserManagementRules.role(roles), throwsFormatException),
    );
  }
  for (final role in UserManagementRules.roles) {
    test(
      'rol válido $role y espacios',
      () => expect(UserManagementRules.role([' $role ']), role),
    );
  }
  test(
    'autoedición bloqueada por identidad y por nombre del actor backend',
    () {
      expect(
        UserManagementRules.isSelf(
          admin,
          user(id: '4', username: 'different.test'),
        ),
        isTrue,
      );
      expect(
        UserManagementRules.isSelf(
          admin,
          user(id: '2', username: 'admin.test'),
        ),
        isTrue,
      );
      expect(UserManagementRules.isSelf(admin, user()), isFalse);
      expect(UserManagementRules.label('ROLE_UNKNOWN'), 'Sin rol reconocido');
    },
  );
  for (final record in [(0, 1), (0, 200), (3, 100)]) {
    test(
      'paginación válida $record',
      () => AuditRules.pagination(record.$1, record.$2),
    );
  }
  for (final record in [(-1, 100), (0, 0), (0, 201), (0, -1)]) {
    test(
      'paginación inválida $record',
      () => expect(
        () => AuditRules.pagination(record.$1, record.$2),
        throwsFormatException,
      ),
    );
  }
  for (final metadata in [
    <String, Object>{'description': ' Descripción ficticia '},
    '{"description":" Descripción ficticia "}',
    ' Descripción ficticia ',
  ]) {
    test(
      'descripción preserva contenido y acentos: $metadata',
      () => expect(log(metadata: metadata).description, 'Descripción ficticia'),
    );
  }
  test(
    'descripción usa título o fallback del recurso sin inventar una acción',
    () {
      expect(
        log(metadata: {'description': ' ', 'title': 'Título ficticio'})
            .description,
        'Título ficticio',
      );
      expect(log().description, 'Consulta · Paciente #1');
      expect(log().code, 'AL-1');
      final unknown = AuditLog.fromJson({
        ...logJson(),
        'entityType': 'UNKNOWN',
        'actionType': 'UNKNOWN',
      });
      expect(unknown.entityLabel, 'UNKNOWN');
      expect(unknown.actionLabel, 'UNKNOWN');
    },
  );
  for (final entry in {
    'id': null,
    'performedAt': 'invalid',
    'entityId': '',
    'entityType': true,
    'actionType': {},
    'performedBy': ' ',
  }.entries) {
    test(
      'recurso inválido ${entry.key} no fabrica valor',
      () => expect(
        () => AuditLog.fromJson({...logJson(), entry.key: entry.value}),
        throwsFormatException,
      ),
    );
  }
  test('no sustituye fecha ausente por hora actual', () {
    final json = logJson()..remove('performedAt');
    expect(() => AuditLog.fromJson(json), throwsFormatException);
  });
  test('etiquetas USER y entidades clínicas mantienen contrato desplegado', () {
    for (final type in ['USER', 'MEDICATION_ORDER', 'CARE_PLAN']) {
      expect(
        AuditLog.fromJson({...logJson(), 'entityType': type}).entityLabel,
        isNot('Sistema'),
      );
    }
  });
}
