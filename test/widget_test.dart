import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nurse_pulse_app/main.dart';

void main() {
  testWidgets('App boots and shows the splash screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: NursePulseApp()));

    // Session restoration from secure storage is still in flight — the
    // splash route should be showing before it resolves.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
