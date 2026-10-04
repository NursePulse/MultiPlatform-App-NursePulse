import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/notification/application/alert_notifier.dart';
import 'package:nurse_pulse_app/features/notification/infrastructure/alert_api.dart';
import 'package:nurse_pulse_app/features/notification/presentation/alert_form_dialog.dart';
import 'package:nurse_pulse_app/features/notification/presentation/alert_list_view.dart';
import 'package:nurse_pulse_app/features/patient/application/patient_notifier.dart';

import '../patient/fake_patient_api.dart';
import '../patient/fixtures.dart';
import 'fixtures.dart';

Future<void> mount(
  WidgetTester tester,
  FakeAlertApi api, {
  User staff = nurse,
  bool list = false,
  FakePatientApi? patients,
}) async {
  final catalog =
      patients ??
      (FakePatientApi()..patients = [patientFrom(patientCommand())]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        alertUserProvider.overrideWithValue(staff),
        alertApiProvider.overrideWithValue(api),
        patientNotifierProvider.overrideWith(
          (ref) => PatientNotifier(catalog, () => staff.roles)..load(),
        ),
        alertNotifierProvider.overrideWith(
          (ref) => AlertNotifier(
            api,
            () => ref.read(alertUserProvider),
            (id) async => patientFrom(patientCommand(), id: id),
            audit: (_, _, _, _) async {},
            onChanged: (id, _) => ref.invalidate(alertDetailProvider(id)),
          ),
        ),
      ],
      child: MaterialApp(
        home: list
            ? const AlertListView()
            : Scaffold(
                body: Builder(
                  builder: (context) => FilledButton(
                    onPressed: () => showAlertForm(context),
                    child: const Text('Abrir'),
                  ),
                ),
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (!list) {
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }
}

Future<void> selectPatient(WidgetTester tester) async {
  final dropdown = find.byWidgetPredicate(
    (w) =>
        w is DropdownButtonFormField<String> &&
        w.decoration.labelText == 'Paciente',
  );
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Ana').last);
  await tester.pumpAndSettle();
}

Future<void> description(WidgetTester tester, String text) async {
  final field = find.byKey(const ValueKey('alert-description'));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  tester.testTextInput.hide();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester, {bool settle = true}) async {
  final button = find.widgetWithText(FilledButton, 'Guardar');
  await tester.ensureVisible(button);
  await tester.tap(button);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  testWidgets('no autoselecciona paciente; campos obligatorios no llaman API', (
    tester,
  ) async {
    final api = FakeAlertApi();
    await mount(tester, api);
    await save(tester);
    expect(find.text('Selecciona un paciente disponible.'), findsOneWidget);
    expect(find.text('La descripción es obligatoria.'), findsOneWidget);
    expect(api.posts, 0);
    expect(tester.takeException(), isNull);
  });
  for (final text in [' ', 'x' * 256]) {
    testWidgets(
      'descripción inválida de ${text.length} caracteres no llama API',
      (tester) async {
        final api = FakeAlertApi();
        await mount(tester, api);
        await selectPatient(tester);
        await description(tester, text);
        await save(tester);
        expect(api.posts, 0);
        expect(find.byType(AlertFormDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final length in [1, 255]) {
    testWidgets('límite válido $length y trim guardan una vez', (tester) async {
      final api = FakeAlertApi();
      await mount(tester, api);
      await selectPatient(tester);
      await description(tester, ' ${'x' * length} ');
      await save(tester);
      expect(api.posts, 1);
      expect(api.sent!['description'], 'x' * length);
      expect(find.byType(AlertFormDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('error recuperable conserva texto, paciente, tipo y severidad', (
    tester,
  ) async {
    final api = FakeAlertApi()..failure = httpFailure(400);
    await mount(tester, api);
    await selectPatient(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('alert-type')));
    await tester.tap(find.byKey(const ValueKey('alert-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alerta de medicación').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('alert-severity')));
    await tester.tap(find.byKey(const ValueKey('alert-severity')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alta').last);
    await tester.pumpAndSettle();
    await description(tester, ' Texto ficticio conservado ');
    await save(tester);
    expect(find.text('Rechazo simulado 400'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('alert-description')),
          )
          .controller!
          .text,
      ' Texto ficticio conservado ',
    );
    expect(api.sent!['type'], 'MEDICATION');
    expect(api.sent!['severity'], 'HIGH');
    api.failure = null;
    await save(tester);
    expect(api.posts, 2);
    expect(api.sent!['patientId'], '1');
    expect(api.sent!['type'], 'MEDICATION');
    expect(api.sent!['severity'], 'HIGH');
    expect(find.byType(AlertFormDialog), findsNothing);
  });
  testWidgets('doble guardado, cancelar y campos bloqueados mientras envía', (
    tester,
  ) async {
    final gate = Completer<AlertWriteReceipt>();
    final api = FakeAlertApi()..writing = () => gate.future;
    await mount(tester, api);
    await selectPatient(tester);
    await description(tester, 'Texto ficticio');
    await save(tester, settle: false);
    expect(api.posts, 1);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancelar'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('alert-description')),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardando…'))
          .onPressed,
      isNull,
    );
    gate.complete(AlertWriteReceipt(id: '9', alert: alert()));
    await tester.pumpAndSettle();
    expect(api.posts, 1);
    expect(find.byType(AlertFormDialog), findsNothing);
  });
  testWidgets(
    'confirmación ilegible cierra formulario y muestra aviso sin POST extra',
    (tester) async {
      final api = FakeAlertApi()
        ..receipt = AlertWriteReceipt(
          id: '9',
          readError: StateError('detalle simulado'),
        );
      await mount(tester, api);
      await selectPatient(tester);
      await description(tester, 'Texto ficticio');
      await save(tester);
      expect(find.byType(AlertFormDialog), findsNothing);
      expect(api.posts, 1);
      expect(find.textContaining('no repitas'), findsOneWidget);
    },
  );
  testWidgets('catálogo vacío bloquea guardado y permite recargar', (
    tester,
  ) async {
    final api = FakeAlertApi();
    final patients = FakePatientApi();
    await mount(tester, api, patients: patients);
    expect(find.text('Recargar pacientes'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar'))
          .onPressed,
      isNull,
    );
    patients.patients = [patientFrom(patientCommand())];
    await tester.tap(find.text('Recargar pacientes'));
    await tester.pumpAndSettle();
    await selectPatient(tester);
    await description(tester, 'Texto ficticio');
    await save(tester);
    expect(api.posts, 1);
  });
  testWidgets('catálogo fallido se recupera sin perder descripción', (
    tester,
  ) async {
    final patients = FakePatientApi()..failure = httpFailure(503);
    final api = FakeAlertApi();
    await mount(tester, api, patients: patients);
    await description(tester, 'Texto ficticio');
    expect(find.text('Rechazo simulado 503'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar'))
          .onPressed,
      isNull,
    );
    patients.failure = null;
    patients.patients = [patientFrom(patientCommand())];
    await tester.ensureVisible(find.text('Recargar pacientes'));
    await tester.tap(find.text('Recargar pacientes'));
    await tester.pumpAndSettle();
    await selectPatient(tester);
    await save(tester);
    expect(api.posts, 1);
    expect(api.sent!['description'], 'Texto ficticio');
  });
  testWidgets('Nurse puede atender y espera cierre médico; no cierra OPEN', (
    tester,
  ) async {
    final api = FakeAlertApi()
      ..alerts = [alert(), alert(id: '10', status: 'ATTENDED')];
    await mount(tester, api, list: true);
    expect(find.text('Atender'), findsOneWidget);
    expect(find.text('Cerrar'), findsNothing);
    expect(find.text('Pendiente de cierre médico.'), findsOneWidget);
    expect(find.text('Registrar alerta'), findsOneWidget);
  });
  for (final staff in [doctor, admin]) {
    testWidgets('${staff.username}: cierra solo atendidas', (tester) async {
      final api = FakeAlertApi()
        ..alerts = [alert(), alert(id: '10', status: 'ATTENDED')];
      await mount(tester, api, list: true, staff: staff);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('Cerrar'), findsOneWidget);
      expect(find.text('Pendiente de cierre médico.'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'desconocido no ve acciones de escritura y formulario bloqueado',
    (tester) async {
      const unknown = User(id: '7', username: 'unknown', roles: []);
      final api = FakeAlertApi();
      await mount(tester, api, staff: unknown, list: true);
      expect(find.text('Registrar alerta'), findsNothing);
      expect(api.reads, 0);
      await mount(tester, api, staff: unknown);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar'))
            .onPressed,
        isNull,
      );
      expect(api.posts, 0);
    },
  );
  testWidgets(
    'filtros: críticas/moderadas, cerradas excluidas y paciente reactivo',
    (tester) async {
      final api = FakeAlertApi()
        ..alerts = [
          alert(),
          alert(id: '10', severity: 'LOW'),
          alert(id: '11', status: 'CLOSED'),
        ];
      await mount(tester, api, list: true);
      expect(find.text('2 alertas pendientes'), findsOneWidget);
      await tester.tap(find.text('Críticas'));
      await tester.pumpAndSettle();
      expect(find.text('Crítica'), findsOneWidget);
      expect(find.text('Baja'), findsNothing);
      expect(find.textContaining('Ana'), findsOneWidget);
      await tester.tap(find.text('Moderadas'));
      await tester.pumpAndSettle();
      expect(find.text('Baja'), findsOneWidget);
      expect(find.text('Crítica'), findsNothing);
      expect(find.text('Cerrada'), findsNothing);
    },
  );
  testWidgets('fallo de listado reintenta GET y vacío admite refresco', (
    tester,
  ) async {
    final api = FakeAlertApi()..readFailure = httpFailure(503);
    await mount(tester, api, list: true);
    expect(find.text('Rechazo simulado 503'), findsOneWidget);
    api.readFailure = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('No hay alertas en este filtro.'), findsOneWidget);
    expect(find.text('Rechazo simulado 503'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(api.reads, greaterThanOrEqualTo(3));
    expect(api.writes, 0);
  });
  testWidgets('detalle por ID: error/reintento GET y fecha ausente explícita', (
    tester,
  ) async {
    final api = FakeAlertApi()
      ..alerts = [alert()]
      ..detailFailure = httpFailure(503)
      ..current = alert(date: null);
    await mount(tester, api, list: true);
    await tester.tap(find.text('Ver detalle'));
    await tester.pumpAndSettle();
    expect(find.text('Rechazo simulado 503'), findsOneWidget);
    api.detailFailure = null;
    await tester.tap(find.text('Reintentar detalle'));
    await tester.pumpAndSettle();
    expect(find.text('Generada: Sin información'), findsOneWidget);
    expect(api.detailReads, 2);
    expect(api.writes, 0);
  });
  testWidgets('acción fallida no cambia status, permite intento manual', (
    tester,
  ) async {
    final api = FakeAlertApi()
      ..alerts = [alert()]
      ..failure = httpFailure(403);
    await mount(tester, api, list: true);
    await tester.tap(find.text('Atender'));
    await tester.pumpAndSettle();
    expect(find.text('Rechazo simulado 403'), findsOneWidget);
    expect(find.text('Activa'), findsOneWidget);
    expect(api.attends, 1);
    api.failure = null;
    await tester.tap(find.text('Atender'));
    await tester.pumpAndSettle();
    expect(api.attends, 2);
    expect(find.text('Atendida'), findsOneWidget);
    expect(find.text('Atender'), findsNothing);
  });
}
