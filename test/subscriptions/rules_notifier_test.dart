import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/subscriptions/application/payment_validation.dart';
import 'package:nurse_pulse_app/features/subscriptions/domain/payment.dart';
import 'package:nurse_pulse_app/features/subscriptions/domain/plan.dart';

import 'fixtures.dart';

void main() {
  test('volver al plan gratuito descarta el recibo anterior y permite un nuevo checkout', () async {
    final store = PlanStore(), gateway = Gateway();
    final n = notifier(store, gateway);
    addTearDown(n.dispose);
    await pay(n);
    expect(n.state.receipt, isNotNull);
    await n.selectPlan(PlanId.essential);
    expect(n.state.receipt, isNull);
    expect(n.state.planId, PlanId.essential);
    await pay(n);
    expect(gateway.calls, 2);
    expect(n.state.planId, PlanId.professional);
  });
  test(
    'plan pendiente confirmado impide cambiar de plan sin guardar primero',
    () async {
      final store = PlanStore()..writeFailure = StateError('Error simulado');
      final gateway = Gateway();
      final n = notifier(store, gateway);
      addTearDown(n.dispose);
      await expectLater(pay(n), throwsStateError);
      await expectLater(n.selectPlan(PlanId.essential), throwsFormatException);
      expect(n.state.pendingPlan, PlanId.professional);
      expect(gateway.calls, 1);
    },
  );
  test('catálogo web: precios, plazas, módulos y recomendado', () {
    expect(kPlanCatalog.map((p) => p.monthlyPrice), [0, 49, 129]);
    expect(kPlanCatalog.map((p) => p.maxSeats), [5, 25, 100]);
    expect(kPlanCatalog.map((p) => p.highlighted), [false, true, false]);
    expect(kPlanCatalog.last.features, contains('Auditoría'));
  });
  for (final length in [0, 2, 81]) {
    test(
      'titular inválido $length',
      () => expect(CheckoutRules.name('a' * length), isNotNull),
    );
  }
  for (final length in [3, 80]) {
    test(
      'titular válido $length',
      () => expect(CheckoutRules.name('a' * length), isNull),
    );
  }
  for (final value in [
    '',
    'a@',
    'a..b@example.test',
    'a @example.test',
    'a@-example.test',
    'a@${'x' * 64}.test',
    '${'a' * 65}@example.test',
    '${'a' * 64}@${'b' * 51}.test',
  ]) {
    test(
      'email inválido ${value.length}',
      () => expect(CheckoutRules.email(value), isNotNull),
    );
  }
  test('email Angular válido hasta 120 con trim', () {
    expect(CheckoutRules.email(' a+b@example.test '), isNull);
    expect(CheckoutRules.email('${'a' * 64}@${'b' * 50}.test'), isNull);
  });
  for (final type in BillingDocumentType.values) {
    test('${type.name} obliga dígitos y longitud exacta', () {
      final size = type == BillingDocumentType.dni ? 8 : 11;
      expect(CheckoutRules.document(type, '0' * size), isNull);
      for (final value in [
        '0' * (size - 1),
        '0' * (size + 1),
        'a${'0' * size}',
        '0 0000001',
      ]) {
        expect(CheckoutRules.document(type, value), isNotNull);
      }
    });
  }
  test('formato, marcas y Luhn coinciden con la web', () {
    expect(formatCardNumber('4242424242424242'), demoCard);
    expect(formatExpiry('1026'), '10/26');
    expect(detectCardBrand(demoCard), CardBrand.visa);
    expect(detectCardBrand('51'), CardBrand.mastercard);
    expect(detectCardBrand('27'), CardBrand.mastercard);
    expect(detectCardBrand('37'), CardBrand.amex);
    expect(isValidCardNumber(demoCard), isTrue);
    expect(isValidCardNumber('4242 4242 4242 4241'), isFalse);
    expect(isValidCardNumber('123'), isFalse);
    expect(isValidCardNumber('0' * 20), isFalse);
  });
  test('vencimiento vigente hasta fin de mes y CVV de 3–4 dígitos', () {
    expect(isValidFutureExpiry('10/26', now), isTrue);
    expect(isValidFutureExpiry('09/26', now), isFalse);
    for (final value in ['00/26', '13/26', '1/26', '10/2', 'texto']) {
      expect(isValidFutureExpiry(value, now), isFalse);
    }
    expect(isValidFutureExpiry('01/27', now), isTrue);
    expect(isValidSecurityCode('123'), isTrue);
    expect(isValidSecurityCode('1234'), isTrue);
    expect(isValidSecurityCode('12'), isFalse);
    expect(isValidSecurityCode('12345'), isFalse);
  });
  for (final actor in [
    null,
    const User(id: '9', username: 'unknown.test', roles: ['UNKNOWN']),
  ]) {
    test(
      'sin sesión válida no consulta plan ni inicia simulación ${actor?.username}',
      () async {
        final store = PlanStore(), gateway = Gateway();
        final n = notifier(store, gateway, actor: actor);
        addTearDown(n.dispose);
        await n.load();
        await expectLater(pay(n), throwsFormatException);
        await expectLater(
          n.selectPlan(PlanId.essential),
          throwsFormatException,
        );
        expect(store.reads, 0);
        expect(store.writes, 0);
        expect(gateway.calls, 0);
      },
    );
  }
  for (final stored in [
    null,
    'garbage',
    'essential',
    'professional',
    'enterprise',
  ]) {
    test('restaura plan $stored y conserva fallback web', () async {
      final store = PlanStore()..stored = stored;
      final n = notifier(store, Gateway());
      addTearDown(n.dispose);
      await n.load();
      expect(
        n.state.planId.name,
        ['professional', 'enterprise'].contains(stored) ? stored : 'essential',
      );
    });
  }
  for (final actor in [nurse, doctor, admin]) {
    test(
      '${actor.primaryRole} completa simulación y restaura solo ID de plan',
      () async {
        final store = PlanStore(), gateway = Gateway();
        final n = notifier(store, gateway, actor: actor);
        addTearDown(n.dispose);
        await n.load();
        final receipt = await pay(n);
        expect(receipt.transactionId, 'PR-FICTICIO');
        expect(n.state.planId, PlanId.professional);
        expect(store.stored, 'professional');
        expect(gateway.request!.currency, 'USD');
        expect(gateway.request!.cardholderName, 'Titular ficticio');
        expect(gateway.request!.billingEmail, 'billing@example.test');
        expect(gateway.request!.cardLastFour, '4242');
        final restarted = notifier(store, gateway, actor: actor);
        addTearDown(restarted.dispose);
        await restarted.load();
        expect(restarted.state.planId, PlanId.professional);
        expect(gateway.calls, 1);
      },
    );
  }
  for (final field in ['name', 'email', 'document', 'card', 'expiry', 'cvv']) {
    test('$field inválido impide gateway y persistencia', () async {
      final store = PlanStore(), gateway = Gateway();
      final n = notifier(store, gateway);
      addTearDown(n.dispose);
      await expectLater(
        pay(
          n,
          name: field == 'name' ? ' ' : 'Nombre ficticio',
          email: field == 'email' ? 'a@' : 'billing@example.test',
          document: field == 'document' ? '123' : '00000001',
          card: field == 'card' ? '123' : demoCard,
          expiry: field == 'expiry' ? '09/26' : '10/26',
          cvv: field == 'cvv' ? '12' : '123',
        ),
        throwsFormatException,
      );
      expect(gateway.calls, 0);
      expect(store.writes, 0);
      expect(n.state.processing, isFalse);
    });
  }
  test('RUC válido y plan enterprise respetan precio de catálogo', () async {
    final gateway = Gateway();
    final n = notifier(PlanStore(), gateway);
    addTearDown(n.dispose);
    await pay(
      n,
      plan: PlanId.enterprise,
      documentType: BillingDocumentType.ruc,
      document: '00000000001',
    );
    expect(gateway.request!.amount, 129);
    expect(n.state.planId, PlanId.enterprise);
  });
  test(
    'selección gratuita no llama gateway; pago obligatorio para plan premium',
    () async {
      final store = PlanStore()..stored = 'professional';
      final gateway = Gateway();
      final n = notifier(store, gateway);
      addTearDown(n.dispose);
      await n.load();
      await expectLater(n.selectPlan(PlanId.enterprise), throwsFormatException);
      await n.selectPlan(PlanId.essential);
      expect(store.stored, 'essential');
      expect(gateway.calls, 0);
      await n.selectPlan(PlanId.essential);
      expect(store.writes, 1);
    },
  );
  test('fallo gateway conserva plan y admite reintento explícito', () async {
    final store = PlanStore(),
        gateway = Gateway()..failure = StateError('Rechazo simulado');
    final n = notifier(store, gateway);
    addTearDown(n.dispose);
    await expectLater(pay(n), throwsStateError);
    expect(n.state.planId, PlanId.essential);
    expect(n.state.error, isNotNull);
    expect(store.writes, 0);
    gateway.failure = null;
    await pay(n);
    expect(gateway.calls, 2);
    expect(store.writes, 1);
    expect(n.state.error, isNull);
  });
  test('simulación confirmada y guardado fallido: reintenta almacenamiento sin repetir gateway', () async {
    final store = PlanStore()..writeFailure = StateError('Error simulado');
    final gateway = Gateway();
    final n = notifier(store, gateway);
    addTearDown(n.dispose);
    await expectLater(pay(n), throwsStateError);
    expect(n.state.pendingPlan, PlanId.professional);
    expect(n.state.receipt, isNotNull);
    expect(n.state.planId, PlanId.essential);
    await n.load();
    await expectLater(pay(n), throwsFormatException);
    expect(gateway.calls, 1);
    store.writeFailure = null;
    await n.selectPlan(PlanId.professional);
    expect(n.state.pendingPlan, isNull);
    expect(store.stored, 'professional');
    expect(gateway.calls, 1);
  });
  test('recibo de otra operación no publica éxito ni cambia plan', () async {
    final gateway = Gateway()
      ..result = (request) => PaymentReceipt(
        request: PaymentRequest(
          planId: PlanId.enterprise,
          amount: 129,
          billingEmail: request.billingEmail,
          cardholderName: request.cardholderName,
          cardLastFour: request.cardLastFour,
        ),
        transactionId: 'PR-FICTICIO',
        paidAt: now,
      );
    final store = PlanStore();
    final n = notifier(store, gateway);
    addTearDown(n.dispose);
    await expectLater(pay(n), throwsFormatException);
    expect(store.writes, 0);
    expect(n.state.receipt, isNull);
  });
  test(
    'doble pago y selección bloqueados mientras gateway está pendiente',
    () async {
      final gateway = Gateway()..gate = Completer<PaymentReceipt>();
      final store = PlanStore();
      final n = notifier(store, gateway);
      addTearDown(n.dispose);
      final pending = pay(n);
      await expectLater(pay(n), throwsFormatException);
      await expectLater(n.selectPlan(PlanId.essential), throwsFormatException);
      gateway.gate!.complete(
        PaymentReceipt(
          request: gateway.request!,
          transactionId: 'PR-FICTICIO',
          paidAt: now,
        ),
      );
      await pending;
      expect(gateway.calls, 1);
      expect(store.writes, 1);
    },
  );
  test('cargas simultáneas comparten lectura; no pisan selección', () async {
    final store = PlanStore()..reading = Completer<String?>();
    final gateway = Gateway();
    final n = notifier(store, gateway);
    addTearDown(n.dispose);
    final a = n.load(), b = n.load();
    await expectLater(pay(n), throwsFormatException);
    expect(store.reads, 1);
    store.reading!.complete('enterprise');
    await Future.wait([a, b]);
    expect(n.state.planId, PlanId.enterprise);
    expect(gateway.calls, 0);
  });
  test('error de lectura libera carga y admite recuperación', () async {
    final store = PlanStore()..readFailure = StateError('Error simulado');
    final n = notifier(store, Gateway());
    addTearDown(n.dispose);
    await n.load();
    expect(n.state.error, isNotNull);
    expect(n.state.loading, isFalse);
    store.readFailure = null;
    store.stored = 'enterprise';
    await n.load();
    expect(n.state.planId, PlanId.enterprise);
    expect(n.state.error, isNull);
  });
  test('cambio de sesión durante gateway impide persistencia y exposición de recibo', () async {
    User? actor = admin;
    final store = PlanStore(),
        gateway = Gateway()..gate = Completer<PaymentReceipt>();
    final n = notifier(store, gateway, user: () => actor);
    addTearDown(n.dispose);
    final pending = pay(n);
    actor = null;
    gateway.gate!.complete(
      PaymentReceipt(
        request: gateway.request!,
        transactionId: 'PR-FICTICIO',
        paidAt: now,
      ),
    );
    await expectLater(pending, throwsFormatException);
    expect(store.writes, 0);
    expect(n.state.receipt, isNull);
  });
  test(
    'notifier descartado mientras gateway responde no escribe preferencias',
    () async {
      final store = PlanStore(),
          gateway = Gateway()..gate = Completer<PaymentReceipt>();
      final n = notifier(store, gateway);
      final pending = pay(n);
      n.dispose();
      gateway.gate!.complete(
        PaymentReceipt(
          request: gateway.request!,
          transactionId: 'PR-FICTICIO',
          paidAt: now,
        ),
      );
      await expectLater(pending, throwsFormatException);
      expect(store.writes, 0);
    },
  );
}
