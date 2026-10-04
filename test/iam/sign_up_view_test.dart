import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/iam/application/auth_notifier.dart';
import 'package:nurse_pulse_app/features/iam/domain/sign_up_request.dart';
import 'package:nurse_pulse_app/features/iam/presentation/sign_up_view.dart';

Finder field(String key) => find.byKey(ValueKey('register-$key'));

Future<void> showForm(
  WidgetTester tester,
  Future<void> Function(SignUpRequest) submit,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [registrationSubmitProvider.overrideWithValue(submit)],
      child: const MaterialApp(home: SignUpView()),
    ),
  );
}

Future<void> fillForm(WidgetTester tester) async {
  for (final entry in {
    'username': 'nurse.test',
    'firstName': 'María',
    'lastName': 'Núñez',
    'phone': '912345678',
    'age': '18',
    'email': 'maria@example.com',
    'password': 'TestPass123!x',
    'confirm': 'TestPass123!x',
  }.entries) {
    await tester.ensureVisible(field(entry.key));
    await tester.enterText(field(entry.key), entry.value);
  }

  tester.testTextInput.hide();
  await tester.pump();
}

Future<void> submitForm(WidgetTester tester) async {
  tester.testTextInput.hide();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();

  await tester.ensureVisible(field('submit'));
  await tester.pumpAndSettle();

  expect(field('submit').hitTestable(), findsOneWidget);
  await tester.tap(field('submit'));
  await tester.pump();
}

void main() {
  testWidgets('vacíos muestran errores y no envían', (tester) async {
    var calls = 0;
    await showForm(tester, (_) async {
      calls++;
    });

    await submitForm(tester);
    expect(calls, 0);
    expect(
      find.text('El usuario debe tener entre 3 y 50 caracteres.'),
      findsOneWidget,
    );
    expect(
      find.text('La edad debe ser un número entero entre 18 y 120.'),
      findsOneWidget,
    );
  });

  testWidgets('edad y confirmación inválidas bloquean la API', (tester) async {
    var calls = 0;
    await showForm(tester, (_) async {
      calls++;
    });

    await fillForm(tester);
    await tester.enterText(field('age'), '17');
    await submitForm(tester);
    expect(calls, 0);

    await tester.enterText(field('age'), '18');
    await tester.enterText(field('confirm'), 'TestPass123!y');
    await submitForm(tester);
    expect(calls, 0);
    expect(find.text('Las contraseñas deben coincidir.'), findsOneWidget);
  });

  testWidgets('válido envía completo una sola vez y muestra éxito', (
    tester,
  ) async {
    final pending = Completer<void>();
    final requests = <SignUpRequest>[];

    await showForm(tester, (request) {
      requests.add(request);
      return pending.future;
    });

    await fillForm(tester);
    await submitForm(tester);
    await tester.tap(field('submit'));
    await tester.pump();

    expect(requests.length, 1);
    expect(requests.single.age, 18);
    expect(requests.single.phone, '912345678');
    expect(requests.single.firstName, 'María');

    pending.complete();
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Te enviamos un correo para confirmarla. Abre el enlace antes de '
        'iniciar sesión.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('HTTP 400 muestra detalle real y conserva los datos', (
    tester,
  ) async {
    await showForm(tester, (_) async {
      final options = RequestOptions(path: '/authentication/sign-up');
      throw DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 400,
          data: {'detail': 'El teléfono no es válido.'},
        ),
      );
    });

    await fillForm(tester);
    await submitForm(tester);
    await tester.pumpAndSettle();

    expect(find.text('El teléfono no es válido.'), findsOneWidget);
    final username = tester.widget<TextFormField>(field('username'));
    expect(username.controller!.text, 'nurse.test');
    expect(tester.widget<FilledButton>(field('submit')).onPressed, isNotNull);
  });

  testWidgets('teléfono pegado se normaliza y edad decimal se rechaza', (
    tester,
  ) async {
    await showForm(tester, (_) async {});

    await tester.enterText(field('phone'), '912-345-678');
    expect(
      tester.widget<TextFormField>(field('phone')).controller!.text,
      '912345678',
    );

    await tester.enterText(field('age'), '18.5');
    expect(
      tester.widget<TextFormField>(field('age')).controller!.text,
      isEmpty,
    );
  });
}
