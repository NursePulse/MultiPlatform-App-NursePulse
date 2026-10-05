import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/clinical_event/application/clinical_event_effects.dart';
import 'package:nurse_pulse_app/features/clinical_event/application/clinical_event_notifier.dart';
import 'package:nurse_pulse_app/features/clinical_event/domain/clinical_event.dart';
import 'package:nurse_pulse_app/features/clinical_event/presentation/clinical_event_form_dialog.dart';
import 'package:nurse_pulse_app/features/clinical_event/presentation/clinical_event_list_view.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/patient/application/patient_notifier.dart';

import '../patient/fake_patient_api.dart';
import '../patient/fixtures.dart';
import 'fixtures.dart';

Future<void> mount(
  WidgetTester tester,
  FakeEventApi api, {
  User staff = actor,
  bool list = false,
  FakePatientApi? patients,
  ClinicalEventEffects? effects,
}) async {
  final patientApi =
      patients ??
      (FakePatientApi()..patients = [patientFrom(patientCommand())]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clinicalEventUserProvider.overrideWithValue(staff),
        patientNotifierProvider.overrideWith(
          (ref) => PatientNotifier(patientApi, () => staff.roles)..load(),
        ),
        clinicalEventNotifierProvider.overrideWith(
          (ref) => ClinicalEventNotifier(
            api,
            () => ref.read(clinicalEventUserProvider),
            (id) async => patientFrom(patientCommand(), id: id),
            effects ??
                ClinicalEventEffects(
                  audit: (_, _) async {},
                  createAlert: (_, _) async {},
                ),
          ),
        ),
      ],
      child: MaterialApp(
        home: list
            ? const ClinicalEventListView()
            : Scaffold(
                body: Builder(
                  builder: (context) => FilledButton(
                    onPressed: () => showClinicalEventForm(context),
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

Future<void> fill(
  WidgetTester tester, {
  String title = '  Control  ',
  String description = '  Observación ficticia  ',
}) async {
  final patient = find.byWidgetPredicate(
    (w) =>
        w is DropdownButtonFormField<String> &&
        w.decoration.labelText == 'Paciente',
  );
  await tester.ensureVisible(patient);
  await tester.tap(patient);
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Ana').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('event-title')), title);
  await tester.enterText(
    find.byKey(const ValueKey('event-description')),
    description,
  );
  tester.testTextInput.hide();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('event-save'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('vacíos: errores junto al campo y ninguna escritura', (
    tester,
  ) async {
    final api = FakeEventApi();
    await mount(tester, api);
    await save(tester);
    expect(find.text('Selecciona un paciente disponible.'), findsOneWidget);
    expect(find.text('Título es obligatorio.'), findsOneWidget);
    expect(find.text('Descripción es obligatorio.'), findsOneWidget);
    expect(api.writes, 0);
    expect(tester.takeException(), isNull);
  });
  for (final invalid in [
    ('abc', 'Observación ficticia'),
    ('x' * 121, 'Observación ficticia'),
    ('Control', 'x' * 9),
    ('Control', 'x' * 1001),
  ]) {
    testWidgets(
      'pegado inválido ${invalid.$1.length}/${invalid.$2.length} no llega a API',
      (tester) async {
        final api = FakeEventApi();
        await mount(tester, api);
        await fill(tester, title: invalid.$1, description: invalid.$2);
        await save(tester);
        expect(api.writes, 0);
        expect(find.byKey(const ValueKey('event-save')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'válido normaliza payload, cierra y confirma una sola escritura',
    (tester) async {
      final api = FakeEventApi();
      await mount(tester, api);
      await fill(tester);
      await save(tester);
      expect(api.writes, 1);
      expect(api.sent!.toJson(), {
        'patientId': 1,
        'eventType': 'OBSERVATION',
        'severity': 'LOW',
        'title': 'Control',
        'description': 'Observación ficticia',
      });
      expect(find.byKey(const ValueKey('event-save')), findsNothing);
      expect(find.text('Evento clínico guardado.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'HTTP 400 conserva formulario y retry explícito cierra al guardar',
    (tester) async {
      final api = FakeEventApi()..failure = httpFailure(400);
      await mount(tester, api);
      await fill(tester);
      await save(tester);
      expect(find.text('Rechazo simulado 400'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('event-title')))
            .controller!
            .text,
        '  Control  ',
      );
      expect(api.writes, 1);
      api.failure = null;
      await save(tester);
      expect(api.writes, 2);
      expect(find.byKey(const ValueKey('event-save')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('doble tap, cancelar y campos bloqueados mientras guarda', (
    tester,
  ) async {
    final api = FakeEventApi();
    final pending = Completer<ClinicalEvent>();
    api.writing = (_) => pending.future;
    await mount(tester, api);
    await fill(tester);
    final button = find.byKey(const ValueKey('event-save'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    expect(api.writes, 1);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('event-cancel')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('event-title')))
          .enabled,
      isFalse,
    );
    pending.complete(eventFrom(api.sent!));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('event-save')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'fallo de alerta conserva éxito y muestra aviso sin repetir evento',
    (tester) async {
      final api = FakeEventApi();
      await mount(
        tester,
        api,
        effects: ClinicalEventEffects(
          audit: (_, _) async {},
          createAlert: (_, _) async => throw StateError('Alerta simulada'),
        ),
      );
      await fill(tester);
      await tester.tap(find.byKey(const ValueKey('event-severity')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crítico').last);
      await tester.pumpAndSettle();
      await save(tester);
      expect(api.writes, 1);
      expect(find.byKey(const ValueKey('event-save')), findsNothing);
      expect(find.textContaining('Revisa Alertas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'rol desconocido no muestra Registrar y Doctor sí puede registrar',
    (tester) async {
      final api = FakeEventApi();
      await mount(
        tester,
        api,
        list: true,
        staff: const User(id: '2', username: 'unknown.test', roles: []),
      );
      expect(find.text('Registrar evento'), findsNothing);
      expect(api.reads, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await mount(
        tester,
        api,
        list: true,
        staff: const User(
          id: '2',
          username: 'doctor.test',
          roles: [kRoleDoctor],
        ),
      );
      expect(find.text('Registrar evento'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('listado conserva eventos y responsable ante error de recarga', (
    tester,
  ) async {
    final api = FakeEventApi()
      ..events = [eventFrom(command(title: 'Evento ficticio'))];
    await mount(tester, api, list: true);
    expect(find.text('Evento ficticio'), findsOneWidget);
    expect(find.textContaining('Responsable: staff.test'), findsOneWidget);
    api.failure = httpFailure(500);
    final context = tester.element(find.byType(ClinicalEventListView));
    final container = ProviderScope.containerOf(context);
    await container.read(clinicalEventNotifierProvider.notifier).load();
    await tester.pumpAndSettle();
    expect(find.text('Evento ficticio'), findsOneWidget);
    expect(find.text('Rechazo simulado 500'), findsOneWidget);
    api.failure = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Rechazo simulado 500'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'catálogo pendiente deshabilita guardar y permite recargar al fallar',
    (tester) async {
      final patients = FakePatientApi()
        ..failure = const FormatException('Catálogo simulado');
      final api = FakeEventApi();
      await mount(tester, api, patients: patients);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('event-save')))
            .onPressed,
        isNull,
      );
      expect(find.text('Catálogo simulado'), findsOneWidget);
      patients.failure = null;
      patients.patients = [patientFrom(patientCommand())];
      await tester.tap(find.text('Recargar pacientes'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('event-save')))
            .onPressed,
        isNotNull,
      );
      expect(api.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
