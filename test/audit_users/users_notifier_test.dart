import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/iam/application/users_notifier.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/iam/infrastructure/iam_api.dart';

import 'fixtures.dart';

void main() {
  late FakeUsersApi api;
  late UsersNotifier notifier;
  User? actor;
  var disposed = false;
  var changes = 0;
  setUp(() {
    api = FakeUsersApi();
    actor = admin;
    changes = 0;
    disposed = false;
    notifier = UsersNotifier(api, () => actor, onChanged: () => changes++);
  });
  tearDown(() {
    if (!disposed) notifier.dispose();
  });

  test('Admin carga usuarios sin pedir catálogo de roles', () async {
    await notifier.load();
    expect(notifier.state.users, hasLength(2));
    expect(api.lists, 1);
    expect(notifier.state.error, isNull);
  });
  for (final forbidden in [
    null,
    nurse,
    doctor,
    const User(id: '1', username: 'unknown.test', roles: ['ROLE_UNKNOWN']),
  ]) {
    test(
      'sin permiso ${forbidden?.username}: cero consultas y escrituras',
      () async {
        actor = forbidden;
        await notifier.load();
        await expectLater(
          notifier.updateRoles('2', [kRoleDoctor]),
          throwsFormatException,
        );
        expect(api.lists + api.details + api.patches, 0);
        expect(notifier.state.users, isEmpty);
      },
    );
  }
  for (final code in [400, 401, 403, 404, 409, 503]) {
    test('listado HTTP $code conserva usuarios y permite reintentar', () async {
      await notifier.load();
      api.failure = httpFailure(code);
      await notifier.load();
      expect(notifier.state.users, hasLength(2));
      expect(notifier.state.error, isNotNull);
      expect(notifier.state.loading, isFalse);
      api.failure = null;
      await notifier.load();
      expect(notifier.state.error, isNull);
    });
  }
  for (final id in ['', '0', '-1', '1.2', 'abc']) {
    test('ID inválido $id no consulta ni escribe', () async {
      await notifier.load();
      await expectLater(
        notifier.updateRoles(id, [kRoleDoctor]),
        throwsFormatException,
      );
      expect(api.details + api.patches, 0);
    });
  }
  for (final roles in [
    <String>[],
    [' '],
    ['ROLE_UNKNOWN'],
    [kRoleNurse, kRoleDoctor],
  ]) {
    test('roles inválidos $roles no consultan ni escriben', () async {
      await notifier.load();
      await expectLater(
        notifier.updateRoles('2', roles),
        throwsFormatException,
      );
      expect(api.details + api.patches, 0);
    });
  }
  test('autoedición y usuario ausente no llaman API', () async {
    await notifier.load();
    await expectLater(
      notifier.updateRoles('4', [kRoleDoctor]),
      throwsFormatException,
    );
    await expectLater(
      notifier.updateRoles('99', [kRoleDoctor]),
      throwsFormatException,
    );
    expect(api.details + api.patches, 0);
  });
  test('autoedición protegida por username aunque ID difiera', () async {
    api.users = [user(username: 'admin.test')];
    await notifier.load();
    await expectLater(
      notifier.updateRoles('2', [kRoleDoctor]),
      throwsFormatException,
    );
    expect(api.details + api.patches, 0);
  });
  test('sin cambio de rol no consulta ni PATCH', () async {
    await notifier.load();
    await notifier.updateRoles('2', [kRoleNurse]);
    expect(api.details + api.patches, 0);
  });
  test(
    'lee estado vigente y actualiza respuesta real con ID normalizado',
    () async {
      await notifier.load();
      await notifier.updateRoles(' 002 ', [' ROLE_DOCTOR ']);
      expect(api.sentId, '2');
      expect(api.sentRoles, [kRoleDoctor]);
      expect(notifier.state.users.first.primaryRole, kRoleDoctor);
      expect(notifier.state.updatedUserId, '2');
      expect(changes, 1);
      await notifier.updateRoles('2', [kRoleDoctor]);
      expect(api.patches, 1);
    },
  );
  test(
    'rol cambiado por otro administrador no provoca PATCH innecesario',
    () async {
      await notifier.load();
      api.latest = user(role: kRoleDoctor);
      await notifier.updateRoles('2', [kRoleDoctor]);
      expect(api.patches, 0);
      expect(notifier.state.users.first.primaryRole, kRoleDoctor);
    },
  );
  test(
    'roles pueden cambiar de ida y vuelta tras confirmaciones válidas',
    () async {
      await notifier.load();
      await notifier.updateRoles('2', [kRoleDoctor]);
      api.latest = user(role: kRoleDoctor);
      await notifier.updateRoles('2', [kRoleNurse]);
      api.latest = user();
      await notifier.updateRoles('2', [kRoleDoctor]);
      expect(api.patches, 3);
    },
  );
  for (final code in [400, 401, 403, 404, 422, 503]) {
    test('PATCH $code preserva rol y desbloquea recuperación', () async {
      await notifier.load();
      api.patchFailure = httpFailure(code);
      await expectLater(
        notifier.updateRoles('2', [kRoleDoctor]),
        throwsA(anything),
      );
      expect(notifier.state.users.first.primaryRole, kRoleNurse);
      expect(notifier.state.saving, isFalse);
      expect(notifier.state.error, isNotNull);
      api.patchFailure = null;
      await notifier.updateRoles('2', [kRoleDoctor]);
      expect(notifier.state.users.first.primaryRole, kRoleDoctor);
    });
  }
  test('404 previo al PATCH no escribe', () async {
    await notifier.load();
    api.detailFailure = httpFailure(404);
    await expectLater(
      notifier.updateRoles('2', [kRoleDoctor]),
      throwsA(anything),
    );
    expect(api.patches, 0);
  });
  test('respuesta confirmada sin detalle bloquea otro PATCH hasta lectura explícita', () async {
    await notifier.load();
    api.receipt = UserRolesWriteReceipt(id: '2', readError: httpFailure(503));
    await notifier.updateRoles('2', [kRoleDoctor]);
    expect(notifier.state.warning, contains('no repitas'));
    expect(notifier.state.unverifiedIds, contains('2'));
    await expectLater(
      notifier.updateRoles('2', [kRoleDoctor]),
      throwsFormatException,
    );
    expect(api.patches, 1);
    api.users = [user(role: kRoleDoctor)];
    await notifier.load();
    expect(notifier.state.unverifiedIds, isEmpty);
    await notifier.updateRoles('2', [kRoleDoctor]);
    expect(api.patches, 1);
  });
  test('respuesta distinta conserva rol real y exige verificación', () async {
    await notifier.load();
    api.receipt = UserRolesWriteReceipt(
      id: '2',
      user: user(role: kRoleAdmin),
    );
    await notifier.updateRoles('2', [kRoleDoctor]);
    expect(notifier.state.users.first.primaryRole, kRoleAdmin);
    expect(notifier.state.warning, isNotNull);
    expect(notifier.state.unverifiedIds, contains('2'));
  });
  test(
    'doble cambio y recarga durante PATCH no duplican ni sobrescriben',
    () async {
      await notifier.load();
      final gate = Completer<UserRolesWriteReceipt>();
      api.writing = () => gate.future;
      final pending = notifier.updateRoles('2', [kRoleDoctor]);
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        notifier.updateRoles('2', [kRoleDoctor]),
        throwsFormatException,
      );
      await notifier.load();
      expect(api.lists, 1);
      expect(api.patches, 1);
      gate.complete(
        UserRolesWriteReceipt(
          id: '2',
          user: user(role: kRoleDoctor),
        ),
      );
      await pending;
      expect(notifier.state.users.first.primaryRole, kRoleDoctor);
    },
  );
  test(
    'recargas simultáneas comparten petición y bloqueo de escritura',
    () async {
      final gate = Completer<List<User>>();
      api.reading = () => gate.future;
      final first = notifier.load(), second = notifier.load();
      expect(api.lists, 1);
      gate.complete(api.users);
      await Future.wait([first, second]);
    },
  );
  test('sesión cambia antes del PATCH: cero escrituras', () async {
    await notifier.load();
    final gate = Completer<User>();
    api.checking = () => gate.future;
    final pending = notifier.updateRoles('2', [kRoleDoctor]);
    actor = doctor;
    gate.complete(user());
    await expectLater(pending, throwsFormatException);
    expect(api.patches, 0);
    expect(notifier.state.users, isEmpty);
  });
  test('dispose durante listado ignora respuesta', () async {
    final gate = Completer<List<User>>();
    api.reading = () => gate.future;
    final pending = notifier.load();
    notifier.dispose();
    disposed = true;
    gate.complete(api.users);
    await expectLater(pending, completes);
  });
  test(
    'sesión cambiada durante listado fallido borra snapshot privado',
    () async {
      await notifier.load();
      final gate = Completer<List<User>>();
      api.reading = () => gate.future;
      final pending = notifier.load();
      actor = user(id: '9', role: kRoleAdmin, username: 'another.admin');
      gate.completeError(httpFailure(503));
      await pending;
      expect(notifier.state.users, isEmpty);
    },
  );
  test(
    'callback fallido después de confirmar no habilita repetición',
    () async {
      notifier.dispose();
      notifier = UsersNotifier(
        api,
        () => actor,
        onChanged: () => throw StateError('Fallo local'),
      );
      await notifier.load();
      await notifier.updateRoles('2', [kRoleDoctor]);
      await notifier.updateRoles('2', [kRoleDoctor]);
      expect(api.patches, 1);
      expect(notifier.state.users.first.primaryRole, kRoleDoctor);
    },
  );
}
