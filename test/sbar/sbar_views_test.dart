import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/patient/application/patient_notifier.dart';
import 'package:nurse_pulse_app/features/sbar/application/sbar_notifier.dart';
import 'package:nurse_pulse_app/features/sbar/infrastructure/sbar_api.dart';
import 'package:nurse_pulse_app/features/sbar/presentation/sbar_form_dialog.dart';
import 'package:nurse_pulse_app/features/sbar/presentation/sbar_list_view.dart';

import '../patient/fake_patient_api.dart';
import '../patient/fixtures.dart';
import 'fixtures.dart';

Future<void> mount(
  WidgetTester tester,
  FakeSbarApi api, {
  User staff = actor,
  bool list = false,
  List<User>? directory,
  Future<List<User>> Function()? directoryLoader,
  bool settle = true,
}) async {
  final users =
      directory ??
      [
        actor,
        receiver,
        const User(id: '4', username: 'doctor.test', roles: [kRoleDoctor]),
      ];
  final patients = FakePatientApi()..patients = [patientFrom(patientCommand())];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sbarUserProvider.overrideWithValue(staff),
        sbarApiProvider.overrideWithValue(api),
        sbarUsersProvider.overrideWith(
          (ref) async => directoryLoader == null ? users : directoryLoader(),
        ),
        patientNotifierProvider.overrideWith(
          (ref) => PatientNotifier(patients, () => staff.roles)..load(),
        ),
        sbarNotifierProvider.overrideWith(
          (ref) => SbarNotifier(
            api,
            () => ref.read(sbarUserProvider),
            () async => patients.patients,
            (id) async => patientFrom(patientCommand(), id: id),
            () async => users,
            audit: (_, _, _) async {},
            onChanged: (id) => ref.invalidate(sbarDetailProvider(id)),
          ),
        ),
      ],
      child: MaterialApp(
        home: list
            ? const SbarListView()
            : Scaffold(
                body: Builder(
                  builder: (context) => FilledButton(
                    onPressed: () => showSbarForm(context),
                    child: const Text('Abrir'),
                  ),
                ),
              ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  if (!list) {
    await tester.tap(find.text('Abrir'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }
}

const fields = [
  'sbar-situation',
  'sbar-background',
  'sbar-assessment',
  'sbar-recommendation',
];

Future<void> fill(
  WidgetTester tester, {
  String? invalidField,
  String? value,
}) async {
  for (final spec in [
    ('Paciente', 'Ana'),
    ('Personal receptor', 'receiver.test'),
  ]) {
    final dropdown = find.byWidgetPredicate(
      (w) =>
          w is DropdownButtonFormField<String> &&
          w.decoration.labelText == spec.$1,
    );
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(spec.$2).last);
    await tester.pumpAndSettle();
  }
  for (final key in fields) {
    final field = find.byKey(ValueKey(key));
    await tester.ensureVisible(field);
    await tester.enterText(
      field,
      key == invalidField ? value! : '  Texto ficticio  ',
    );
  }
  tester.testTextInput.hide();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('sbar-save'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('vacíos muestran errores por campo y no escriben', (
    tester,
  ) async {
    final api = FakeSbarApi();
    await mount(tester, api);
    await save(tester);
    expect(find.text('Selecciona un paciente disponible.'), findsOneWidget);
    expect(
      find.text('Selecciona un receptor Nurse disponible.'),
      findsOneWidget,
    );
    expect(find.text('Completa S — Situación.'), findsOneWidget);
    expect(find.text('Completa R — Recomendación.'), findsOneWidget);
    expect(api.posts, 0);
    expect(tester.takeException(), isNull);
  });
  for (final key in fields) {
    for (final size in [7, 1001]) {
      testWidgets('$key pegado de $size bloquea POST', (tester) async {
        final api = FakeSbarApi();
        await mount(tester, api);
        await fill(tester, invalidField: key, value: 'x' * size);
        await save(tester);
        expect(api.posts, 0);
        expect(find.byKey(const ValueKey('sbar-save')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('válido envía título generado, cuatro campos trim y receptor', (
    tester,
  ) async {
    final api = FakeSbarApi();
    await mount(tester, api);
    await fill(tester);
    await save(tester);
    expect(api.posts, 1);
    expect(api.sent!.title, startsWith('SBAR -'));
    expect(api.sent!.targetNurseId, '3');
    for (final text in [
      api.sent!.situation,
      api.sent!.background,
      api.sent!.assessment,
      api.sent!.recommendation,
    ]) {
      expect(text, 'Texto ficticio');
    }
    expect(find.byKey(const ValueKey('sbar-save')), findsNothing);
    expect(find.text('Traspaso SBAR guardado.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('HTTP 400 conserva campos y selecciones para retry explícito', (
    tester,
  ) async {
    final api = FakeSbarApi()..failure = httpFailure(400);
    await mount(tester, api);
    await fill(tester);
    await save(tester);
    expect(find.text('Rechazo simulado 400'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('sbar-situation')))
          .controller!
          .text,
      '  Texto ficticio  ',
    );
    expect(find.text('receiver.test'), findsOneWidget);
    api.failure = null;
    await save(tester);
    expect(api.posts, 2);
    expect(find.byKey(const ValueKey('sbar-save')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('POST confirmado y GET fallido cierra sin permitir reenviar', (
    tester,
  ) async {
    final api = FakeSbarApi()
      ..receipt = SbarWriteReceipt(id: '9', readError: httpFailure(503));
    await mount(tester, api);
    await fill(tester);
    await save(tester);
    expect(api.posts, 1);
    expect(find.byKey(const ValueKey('sbar-save')), findsNothing);
    expect(find.textContaining('no vuelvas a registrarlo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('doble tap bloquea escritura, cancelación y campos', (
    tester,
  ) async {
    final api = FakeSbarApi();
    final pending = Completer<SbarWriteReceipt>();
    api.writing = () => pending.future;
    await mount(tester, api);
    await fill(tester);
    final button = find.byKey(const ValueKey('sbar-save'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    expect(api.posts, 1);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('sbar-cancel')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('sbar-situation')))
          .enabled,
      isFalse,
    );
    pending.complete(SbarWriteReceipt(id: '9', transfer: transfer()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('catálogo Nurse excluye usuario actual y Doctor', (tester) async {
    final api = FakeSbarApi();
    await mount(tester, api);
    final dropdown = find.byWidgetPredicate(
      (w) =>
          w is DropdownButtonFormField<String> &&
          w.decoration.labelText == 'Personal receptor',
    );
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    expect(find.text('receiver.test'), findsOneWidget);
    expect(find.text('nurse.test'), findsNothing);
    expect(find.text('doctor.test'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('catálogo pendiente deshabilita guardar; error ofrece recarga', (
    tester,
  ) async {
    final pending = Completer<List<User>>();
    var fail = false;
    final api = FakeSbarApi();
    await mount(
      tester,
      api,
      settle: false,
      directoryLoader: () => fail ? Future.value([receiver]) : pending.future,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('sbar-save')))
          .onPressed,
      isNull,
    );
    pending.completeError(const FormatException('Directorio simulado'));
    await tester.pumpAndSettle();
    expect(find.text('Directorio simulado'), findsOneWidget);
    fail = true;
    final reload = find.text('Recargar receptores');
    await tester.ensureVisible(reload);
    await tester.tap(reload);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('sbar-save')))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Doctor consulta sin creación ni recepción y muestra detalle completo por ID',
    (tester) async {
      final api = FakeSbarApi()..transfers = [transfer()];
      await mount(
        tester,
        api,
        list: true,
        staff: const User(
          id: '4',
          username: 'doctor.test',
          roles: [kRoleDoctor],
        ),
      );
      expect(find.text('Nuevo traspaso'), findsNothing);
      expect(find.byKey(const ValueKey('sbar-ack-9')), findsNothing);
      await tester.tap(find.text('SBAR ficticio'));
      await tester.pumpAndSettle();
      expect(api.detailReads, 1);
      expect(find.text('Antecedentes ficticios'), findsOneWidget);
      expect(find.text('Evaluación ficticia'), findsOneWidget);
      expect(find.text('Recomendación ficticia'), findsOneWidget);
      expect(find.text('Para: receiver.test'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'doble recepción solo hace un PATCH y oculta acción al confirmar',
    (tester) async {
      final api = FakeSbarApi()..transfers = [transfer()];
      final pending = Completer<SbarWriteReceipt>();
      api.writing = () => pending.future;
      await mount(tester, api, list: true);
      final button = find.byKey(const ValueKey('sbar-ack-9'));
      await tester.tap(button);
      await tester.tap(button);
      await tester.pump();
      expect(api.patches, 1);
      expect(tester.widget<IconButton>(button).onPressed, isNull);
      pending.complete(
        SbarWriteReceipt(
          id: '9',
          transfer: transfer(status: 'ACKNOWLEDGED'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sbar-ack-9')), findsNothing);
      expect(find.text('Atendido'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('detalle fallido permite reintentar lectura sin escribir', (
    tester,
  ) async {
    final api = FakeSbarApi()
      ..transfers = [transfer()]
      ..detailFailure = httpFailure(503);
    await mount(tester, api, list: true);
    await tester.tap(find.text('SBAR ficticio'));
    await tester.pumpAndSettle();
    expect(find.text('Rechazo simulado 503'), findsOneWidget);
    api.detailFailure = null;
    await tester.tap(find.text('Reintentar detalle'));
    await tester.pumpAndSettle();
    expect(find.text('Antecedentes ficticios'), findsOneWidget);
    expect(api.posts + api.patches, 0);
    expect(tester.takeException(), isNull);
  });
}
