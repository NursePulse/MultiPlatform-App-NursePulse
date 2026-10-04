import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/core/network/dio_client.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/subscriptions/application/subscription_notifier.dart';
import 'package:nurse_pulse_app/features/subscriptions/domain/payment.dart';
import 'package:nurse_pulse_app/features/subscriptions/presentation/subscription_plans_view.dart';

import 'fixtures.dart';

Future<void> mount(
  WidgetTester tester,
  PlanStore store,
  Gateway gateway, {
  User? actor = admin,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        secureStoreProvider.overrideWithValue(store),
        paymentGatewayProvider.overrideWithValue(gateway),
        subscriptionUserProvider.overrideWithValue(actor),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const SubscriptionPlansView(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> open(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const ValueKey('subscription-select-professional')),
  );
  await tester.tap(
    find.byKey(const ValueKey('subscription-select-professional')),
  );
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester) async {
  for (final entry in [
    ('name', 'Titular ficticio'),
    ('email', 'billing@example.test'),
    ('document', '00000001'),
    ('card', demoCard),
    ('expiry', '1299'),
    ('cvv', '123'),
  ]) {
    await tester.ensureVisible(find.byKey(ValueKey('checkout-${entry.$1}')));
    await tester.enterText(
      find.byKey(ValueKey('checkout-${entry.$1}')),
      entry.$2,
    );
  }
  await tester.ensureVisible(find.byKey(const ValueKey('checkout-pay')));
}

Future<void> payButton(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('checkout-pay')));
  await tester.tap(find.byKey(const ValueKey('checkout-pay')));
  await tester.pumpAndSettle();
}

void main() {
  for (final actor in [
    null,
    const User(id: '9', username: 'unknown.test', roles: ['UNKNOWN']),
  ]) {
    testWidgets(
      'sin sesión clínica válida no selecciona ni lee preferencias ${actor?.username}',
      (tester) async {
        final store = PlanStore(), gateway = Gateway();
        await mount(tester, store, gateway, actor: actor);
        expect(store.reads, 0);
        expect(gateway.calls, 0);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('subscription-select-professional')),
              )
              .onPressed,
          isNull,
        );
      },
    );
  }
  testWidgets(
    'checkout incluye DNI/RUC, aviso de simulación y validaciones antes del gateway',
    (tester) async {
      final store = PlanStore(), gateway = Gateway();
      await mount(tester, store, gateway);
      await open(tester);
      expect(
        find.text('Pago simulado. No se realizan cobros reales.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('checkout-document-type')),
        findsOneWidget,
      );
      await payButton(tester);
      expect(gateway.calls, 0);
      expect(store.writes, 0);
      expect(
        find.text('El titular debe tener entre 3 y 80 caracteres.'),
        findsOneWidget,
      );
    },
  );
  for (final field in ['name', 'email', 'document', 'card', 'expiry', 'cvv']) {
    testWidgets('$field inválido bloquea simulación sin borrar otros campos', (
      tester,
    ) async {
      final store = PlanStore(), gateway = Gateway();
      await mount(tester, store, gateway);
      await open(tester);
      await fill(tester);
      await tester.enterText(find.byKey(ValueKey('checkout-$field')), '');
      await payButton(tester);
      expect(gateway.calls, 0);
      expect(store.writes, 0);
      expect(find.byKey(const ValueKey('checkout-pay')), findsOneWidget);
      if (field != 'name') {
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('checkout-name')),
              )
              .controller!
              .text,
          'Titular ficticio',
        );
      }
    });
  }
  testWidgets(
    'cambiar tipo de documento limpia DNI y permite RUC de 11 dígitos',
    (tester) async {
      final store = PlanStore(), gateway = Gateway();
      await mount(tester, store, gateway);
      await open(tester);
      await fill(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('checkout-document-type')),
      );
      await tester.tap(find.byKey(const ValueKey('checkout-document-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RUC').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('checkout-document')),
            )
            .controller!
            .text,
        '',
      );
      await tester.enterText(
        find.byKey(const ValueKey('checkout-document')),
        '00000000001',
      );
      await payButton(tester);
      expect(gateway.calls, 1);
      expect(store.stored, 'professional');
      expect(find.text('Tarjeta: •••• 4242'), findsOneWidget);
      expect(find.text('Pago simulado aprobado'), findsOneWidget);
      expect(find.byKey(const ValueKey('checkout-card')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('checkout-close')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('subscription-select-professional')),
            )
            .onPressed,
        isNull,
      );
      await mount(tester, store, gateway);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('subscription-select-professional')),
            )
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'fallo de gateway conserva formulario y muestra error recuperable',
    (tester) async {
      final store = PlanStore(),
          gateway = Gateway()..failure = StateError('Error simulado');
      await mount(tester, store, gateway);
      await open(tester);
      await fill(tester);
      await payButton(tester);
      expect(find.byKey(const ValueKey('checkout-error')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('checkout-card')))
            .controller!
            .text,
        demoCard,
      );
      expect(store.writes, 0);
      gateway.failure = null;
      await payButton(tester);
      expect(gateway.calls, 2);
      expect(store.writes, 1);
    },
  );
  testWidgets('guardado fallido reintenta plan sin volver a simular pago', (
    tester,
  ) async {
    final store = PlanStore()..writeFailure = StateError('Error simulado');
    final gateway = Gateway();
    await mount(tester, store, gateway);
    await open(tester);
    await fill(tester);
    await payButton(tester);
    expect(find.byKey(const ValueKey('checkout-save-pending')), findsOneWidget);
    expect(find.byKey(const ValueKey('checkout-pay')), findsNothing);
    expect(find.text('Plan guardado en este dispositivo.'), findsNothing);
    store.writeFailure = null;
    await tester.tap(find.byKey(const ValueKey('checkout-save-pending')));
    await tester.pumpAndSettle();
    expect(gateway.calls, 1);
    expect(store.stored, 'professional');
    expect(find.text('Plan guardado en este dispositivo.'), findsOneWidget);
  });
  testWidgets(
    'doble tap bloquea campos, cancelación y salida hasta confirmar',
    (tester) async {
      final store = PlanStore(),
          gateway = Gateway()..gate = Completer<PaymentReceipt>();
      await mount(tester, store, gateway);
      await open(tester);
      await fill(tester);
      await tester.tap(find.byKey(const ValueKey('checkout-pay')));
      await tester.tap(find.byKey(const ValueKey('checkout-pay')));
      await tester.pump();
      expect(gateway.calls, 1);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('checkout-pay')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('checkout-close')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('checkout-name')))
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<PopScope>(
              find
                  .ancestor(
                    of: find.byKey(const ValueKey('checkout-close')),
                    matching: find.byType(PopScope),
                  )
                  .first,
            )
            .canPop,
        isFalse,
      );
      gateway.gate!.complete(
        PaymentReceipt(
          request: gateway.request!,
          transactionId: 'PR-FICTICIO',
          paidAt: now,
        ),
      );
      await tester.pumpAndSettle();
      expect(store.writes, 1);
    },
  );
  testWidgets(
    '320px y texto ampliado conservan acceso al checkout sin desbordamiento',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, PlanStore(), Gateway(), scale: 2);
      expect(tester.takeException(), isNull);
      await open(tester);
      expect(tester.takeException(), isNull);
      await fill(tester);
      expect(tester.takeException(), isNull);
    },
  );
}
