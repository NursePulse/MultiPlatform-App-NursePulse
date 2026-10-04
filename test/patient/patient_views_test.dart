import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/patient/application/patient_detail.dart';
import 'package:nurse_pulse_app/features/patient/application/patient_notifier.dart';
import 'package:nurse_pulse_app/features/patient/domain/patient_rules.dart';
import 'package:nurse_pulse_app/features/patient/presentation/patient_form_sheet.dart';
import 'package:nurse_pulse_app/features/patient/presentation/patient_list_view.dart';
import 'package:nurse_pulse_app/features/patient/presentation/patient_monitoring_view.dart';

import 'fixtures.dart';
import 'fake_patient_api.dart';

void main() {
  testWidgets('formulario vacío muestra errores y no llama al servidor', (
    tester,
  ) async {
    final api = FakePatientApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patientPermissionsProvider.overrideWithValue(
            const PatientPermissions([kRoleNurse]),
          ),
          patientDoctorsProvider.overrideWith((ref) async => ['Dra. Soto']),
          patientNotifierProvider.overrideWith(
            (ref) => PatientNotifier(api, () => [kRoleNurse]),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: PatientFormSheet())),
      ),
    );

    await tester.pumpAndSettle();

    final button = find.byKey(const ValueKey('patient-save'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Nombre es obligatorio.'), findsOneWidget);
    expect(find.text('Selecciona la fecha de nacimiento.'), findsOneWidget);
    expect(api.writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'doctor no ve creación ni eliminación; búsqueda encuentra documento',
    (tester) async {
      final api = FakePatientApi()..patients = [patientFrom(patientCommand())];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            patientPermissionsProvider.overrideWithValue(
              const PatientPermissions([kRoleDoctor]),
            ),
            patientNotifierProvider.overrideWith(
              (ref) => PatientNotifier(api, () => [kRoleDoctor]),
            ),
          ],
          child: const MaterialApp(home: PatientListView()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Nuevo paciente'), findsNothing);

      await tester.enterText(find.byType(TextField), '00123456');
      await tester.pumpAndSettle();

      expect(find.textContaining('Ana'), findsWidgets);

      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'detalle directo muestra ficha y permite reintentar historial fallido',
    (tester) async {
      var attempts = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            patientDetailProvider('1')
                .overrideWith((ref) async => patientFrom(patientCommand())),
            patientHistoryProvider('1').overrideWith((ref) async {
              attempts++;

              if (attempts == 1) {
                throw const FormatException('Sin historial');
              }

              return const PatientHistory(vitals: [], events: [], alerts: []);
            }),
          ],
          child: const MaterialApp(home: PatientMonitoringView(patientId: '1')),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Documento: 00123456'), findsOneWidget);
      expect(find.text('Sin historial'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(
        find.text('Último riesgo registrado: Sin registros'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('médicos pendientes deshabilitan guardar', (tester) async {
    final pending = Completer<List<String>>();
    final api = FakePatientApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patientPermissionsProvider.overrideWithValue(
            const PatientPermissions([kRoleNurse]),
          ),
          patientDoctorsProvider.overrideWith((ref) => pending.future),
          patientNotifierProvider.overrideWith(
            (ref) => PatientNotifier(api, () => [kRoleNurse]),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: PatientFormSheet())),
      ),
    );

    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('patient-save')))
          .onPressed,
      isNull,
    );

    pending.complete(['Dra. Soto']);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('patient-save')))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'edición conserva datos al fallar y permite guardar al reintentar',
    (tester) async {
      final original = patientFrom(PatientRules.validate(patientCommand()));

      final api = FakePatientApi()
        ..patients = [original]
        ..failure = const FormatException('Servidor no disponible');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            patientPermissionsProvider.overrideWithValue(
              const PatientPermissions([kRoleNurse]),
            ),
            patientDoctorsProvider.overrideWith((ref) async => ['Dra. Soto']),
            patientNotifierProvider.overrideWith(
              (ref) => PatientNotifier(api, () => [kRoleNurse]),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FilledButton(
                  onPressed: () =>
                      showPatientFormSheet(context, editing: original),
                  child: const Text('Abrir edición'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir edición'));
      await tester.pumpAndSettle();

      final name = find.byKey(const ValueKey('patient-first'));
      await tester.enterText(name, 'Rosa');

      Future<void> save() async {
        tester.testTextInput.hide();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();

        final button = find.byKey(const ValueKey('patient-save'));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      await save();

      expect(api.writes, 1);
      expect(find.text('Servidor no disponible'), findsOneWidget);
      expect(tester.widget<TextFormField>(name).controller!.text, 'Rosa');

      api.failure = null;
      await save();

      expect(api.writes, 2);
      expect(api.lastCommand!.firstName, 'Rosa');
      expect(find.byKey(const ValueKey('patient-save')), findsNothing);
      expect(find.text('Paciente guardado.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
