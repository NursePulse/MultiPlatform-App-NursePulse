import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/iam/application/users_notifier.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/iam/infrastructure/iam_api.dart';
import 'package:nurse_pulse_app/features/iam/presentation/user_management_view.dart';

import 'fixtures.dart';

Future<void> mount(
  WidgetTester tester,
  FakeUsersApi api, {
  User? actor = admin,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        usersApiProvider.overrideWithValue(api),
        userManagementActorProvider.overrideWithValue(actor),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const UserManagementView(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('user-edit-2')));
  await tester.pumpAndSettle();
}

void main() {
  for (final actor in [null, nurse, doctor]) {
    testWidgets(
      'administración ${actor?.primaryRole} no consulta ni expone edición',
      (tester) async {
        final api = FakeUsersApi();
        await mount(tester, api, actor: actor);
        expect(api.lists, 0);
        expect(
          find.text('Solo Admin puede administrar usuarios.'),
          findsOneWidget,
        );
        expect(find.byType(OutlinedButton), findsNothing);
      },
    );
  }
  testWidgets('Admin ve contador y su propia cuenta protegida', (tester) async {
    await mount(tester, FakeUsersApi());
    expect(find.text('2 cuentas'), findsOneWidget);
    expect(find.text('admin.test (Tú)'), findsOneWidget);
    expect(find.byKey(const ValueKey('user-edit-4')), findsNothing);
    expect(find.text('No puedes cambiar tu propio rol.'), findsOneWidget);
  });
  testWidgets(
    'rol sin cambio bloquea Aplicar y selección válida confirma solo un PATCH',
    (tester) async {
      final api = FakeUsersApi();
      await mount(tester, api);
      await openDialog(tester);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('user-role-apply')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('user-role-ROLE_DOCTOR')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('user-role-apply')));
      await tester.pumpAndSettle();
      expect(api.patches, 1);
      expect(api.sentRoles, [kRoleDoctor]);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Rol actualizado.'), findsOneWidget);
      expect(find.text('Medicina'), findsOneWidget);
    },
  );
  for (final code in [400, 403, 404, 422, 503]) {
    testWidgets(
      'PATCH $code conserva diálogo y rol elegido para reintento explícito',
      (tester) async {
        final api = FakeUsersApi()..patchFailure = httpFailure(code);
        await mount(tester, api);
        await openDialog(tester);
        await tester.tap(find.byKey(const ValueKey('user-role-ROLE_DOCTOR')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('user-role-apply')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byKey(const ValueKey('user-role-error')), findsOneWidget);
        expect(
          tester
              .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
              .groupValue,
          kRoleDoctor,
        );
        api.patchFailure = null;
        await tester.tap(find.byKey(const ValueKey('user-role-apply')));
        await tester.pumpAndSettle();
        expect(api.patches, 2);
        expect(find.text('Rol actualizado.'), findsOneWidget);
      },
    );
  }
  testWidgets(
    'PATCH confirmado sin detalle cierra diálogo y bloquea repetición',
    (tester) async {
      final api = FakeUsersApi()
        ..receipt = UserRolesWriteReceipt(id: '2', readError: httpFailure(503));
      await mount(tester, api);
      await openDialog(tester);
      await tester.tap(find.byKey(const ValueKey('user-role-ROLE_DOCTOR')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('user-role-apply')));
      await tester.pumpAndSettle();
      expect(api.patches, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const ValueKey('users-warning')), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('user-edit-2')))
            .onPressed,
        isNull,
      );
      api.users = [user(role: kRoleDoctor)];
      await tester.tap(find.byKey(const ValueKey('users-verify')));
      await tester.pumpAndSettle();
      expect(find.text('Medicina'), findsOneWidget);
      expect(find.byKey(const ValueKey('users-warning')), findsNothing);
      expect(api.patches, 1);
    },
  );
  testWidgets('doble tap bloquea selección, cancelar y salida durante cambio', (
    tester,
  ) async {
    final gate = Completer<UserRolesWriteReceipt>();
    final api = FakeUsersApi()..writing = () => gate.future;
    await mount(tester, api);
    await openDialog(tester);
    await tester.tap(find.byKey(const ValueKey('user-role-ROLE_DOCTOR')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('user-role-apply')));
    await tester.tap(find.byKey(const ValueKey('user-role-apply')));
    await tester.pump();
    expect(api.patches, 1);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('user-role-apply')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('user-role-cancel')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<RadioListTile<String>>(
            find.byKey(const ValueKey('user-role-ROLE_ADMIN')),
          )
          .enabled,
      isFalse,
    );
    final popScope = find.ancestor(
      of: find.byType(AlertDialog),
      matching: find.byType(PopScope),
    );
    expect(tester.widget<PopScope>(popScope.first).canPop, isFalse);
    gate.complete(
      UserRolesWriteReceipt(
        id: '2',
        user: user(role: kRoleDoctor),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets('listado vacío admite refresco y errores permiten reintento', (
    tester,
  ) async {
    final api = FakeUsersApi()..users = [];
    await mount(tester, api);
    expect(find.text('No hay usuarios registrados.'), findsOneWidget);
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(api.lists, 2);
    api.failure = httpFailure(503);
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('users-retry')), findsOneWidget);
    api.failure = null;
    api.users = [user()];
    await tester.tap(find.byKey(const ValueKey('users-retry')));
    await tester.pumpAndSettle();
    expect(find.text('nurse.test'), findsOneWidget);
  });
  testWidgets('móvil pequeño y texto ampliado no desbordan lista ni diálogo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, FakeUsersApi(), scale: 2);
    expect(tester.takeException(), isNull);
    await openDialog(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('user-role-cancel')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
