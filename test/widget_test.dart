import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nurse_pulse_app/main.dart';
import 'package:nurse_pulse_app/core/network/dio_client.dart';
import 'package:nurse_pulse_app/core/storage/secure_store.dart';

class EmptySessionStore extends SecureStore {
  @override
  Future<String?> readToken() async => null;

  @override
  Future<Map<String, dynamic>?> readUser() async => null;
}

void main() {
  testWidgets('Sin sesión, la aplicación abre el inicio de sesión', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [secureStoreProvider.overrideWithValue(EmptySessionStore())],
        child: const NursePulseApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));

    await tester.enterText(find.byType(TextFormField).first, 'a');
    await tester.enterText(find.byType(TextFormField).last, '1234567');
    await tester.tap(find.text('Ingresar'));
    await tester.pump();

    expect(
      find.text('El usuario debe tener entre 3 y 50 caracteres.'),
      findsOneWidget,
    );
    expect(
      find.text('La contraseña de acceso debe tener entre 8 y 72 caracteres.'),
      findsOneWidget,
    );
  });
}
