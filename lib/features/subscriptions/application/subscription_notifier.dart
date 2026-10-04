import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_store.dart';
import '../../iam/application/auth_notifier.dart';
import '../../iam/domain/user.dart';
import '../domain/payment.dart';
import '../domain/plan.dart';
import 'payment_validation.dart';

/// Simulación local de la web. No hay pasarela ni cobros reales.
class PaymentGatewayService {
  Future<PaymentReceipt> process(PaymentRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final random = Random.secure();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return PaymentReceipt(
      request: request,
      transactionId:
          'PR-${List.generate(10, (_) => chars[random.nextInt(chars.length)]).join()}',
      paidAt: DateTime.now(),
    );
  }
}

class SubscriptionState {
  const SubscriptionState({
    this.planId = PlanId.essential,
    this.loading = false,
    this.processing = false,
    this.error,
    this.receipt,
    this.pendingPlan,
  });
  final PlanId planId;
  final bool loading, processing;
  final String? error;
  final PaymentReceipt? receipt;
  final PlanId? pendingPlan;
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionNotifier(this._store, this._gateway, this._user)
    : super(const SubscriptionState());
  final SecureStore _store;
  final PaymentGatewayService _gateway;
  final User? Function() _user;
  Future<void>? _loading;
  Plan get currentPlan => kPlanCatalog.firstWhere((p) => p.id == state.planId);
  User _actor() {
    final actor = _user();
    if (actor == null || !actor.hasKnownRole) {
      throw const FormatException('Inicia sesión para seleccionar un plan.');
    }
    return actor;
  }

  bool _same(User actor) {
    final current = _user();
    return mounted &&
        current != null &&
        current.hasKnownRole &&
        current.id == actor.id &&
        current.username == actor.username;
  }

  Future<void> load() {
    if (state.processing || state.pendingPlan != null) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    User? actor;
    try {
      actor = _actor();
      state = SubscriptionState(planId: state.planId, loading: true);
      final stored = await _store.readSubscriptionPlan();
      if (!_same(actor)) return;
      final match = kPlanCatalog
          .where((plan) => plan.id.name == stored)
          .firstOrNull;
      state = SubscriptionState(planId: match?.id ?? PlanId.essential);
    } catch (_) {
      if (mounted) {
        state = SubscriptionState(
          planId: actor != null && _same(actor)
              ? state.planId
              : PlanId.essential,
          error: 'No se pudo cargar el plan guardado. Reintenta.',
        );
      }
    } finally {
      if (mounted && state.loading) {
        state = const SubscriptionState(
          error: 'La sesión cambió. Recarga Suscripciones.',
        );
      }
    }
  }

  Future<void> selectPlan(PlanId planId) async {
    final actor = _actor();
    if (state.processing || state.loading) {
      throw const FormatException(
        'Espera a que termine la operación en curso.',
      );
    }
    if (state.pendingPlan != null && state.pendingPlan != planId) {
      throw const FormatException(
        'Guarda primero el plan pendiente antes de seleccionar otro.',
      );
    }
    if (planId != PlanId.essential && state.pendingPlan != planId) {
      throw const FormatException(
        'Completa primero el pago simulado del plan.',
      );
    }
    if (planId == state.planId && state.pendingPlan == null) return;
    final receipt = state.pendingPlan == planId ? state.receipt : null;
    state = SubscriptionState(
      planId: state.planId,
      processing: true,
      pendingPlan: planId,
      receipt: receipt,
    );
    await _persist(planId, actor, receipt);
  }

  Future<PaymentReceipt> checkout({
    required PlanId planId,
    required String name,
    required String email,
    required BillingDocumentType documentType,
    required String documentNumber,
    required String cardNumber,
    required String expiry,
    required String securityCode,
    DateTime? today,
  }) async {
    final actor = _actor();
    if (state.processing || state.loading || state.pendingPlan != null) {
      throw const FormatException(
        'Espera o guarda el plan pendiente antes de enviar otro pago simulado.',
      );
    }
    if (planId == state.planId || planId == PlanId.essential) {
      throw const FormatException('Selecciona otro plan de pago.');
    }
    final plan = kPlanCatalog.firstWhere((p) => p.id == planId);
    final request = CheckoutRules.fromForm(
      plan: plan,
      nameValue: name,
      emailValue: email,
      documentType: documentType,
      documentNumber: documentNumber,
      cardNumber: cardNumber,
      expiry: expiry,
      securityCode: securityCode,
      today: today,
    );
    state = SubscriptionState(planId: state.planId, processing: true);
    try {
      final receipt = await _gateway.process(request);
      if (!_same(actor)) {
        throw const FormatException('La sesión cambió. Recarga Suscripciones.');
      }
      if (receipt.request.planId != planId ||
          receipt.request.amount != plan.monthlyPrice ||
          receipt.request.cardLastFour != request.cardLastFour ||
          receipt.transactionId.trim().isEmpty) {
        throw const FormatException('No se pudo verificar el recibo simulado.');
      }
      state = SubscriptionState(
        planId: state.planId,
        processing: true,
        receipt: receipt,
        pendingPlan: planId,
      );
      await _persist(planId, actor, receipt);
      return receipt;
    } catch (e) {
      if (mounted && state.processing) {
        state = SubscriptionState(
          planId: _same(actor) ? state.planId : PlanId.essential,
          error: e is FormatException
              ? e.message
              : 'No se pudo completar el pago simulado. Reintenta.',
        );
      }
      rethrow;
    }
  }

  Future<void> _persist(PlanId id, User actor, PaymentReceipt? receipt) async {
    try {
      await _store.saveSubscriptionPlan(id.name);
      if (!_same(actor)) {
        throw const FormatException('La sesión cambió. Recarga Suscripciones.');
      }
      state = SubscriptionState(planId: id, receipt: receipt);
    } catch (_) {
      if (_same(actor)) {
        state = SubscriptionState(
          planId: state.planId,
          receipt: receipt,
          pendingPlan: id,
          error: 'No se pudo guardar el plan. Reintenta el guardado; el pago simulado no se repetirá.',
        );
      }
      rethrow;
    } finally {
      if (mounted && state.processing) {
        state = const SubscriptionState(
          error: 'La sesión cambió. Recarga Suscripciones.',
        );
      }
    }
  }
}

final subscriptionUserProvider = Provider<User?>(
  (ref) => ref.watch(authNotifierProvider.select((s) => s.user)),
);
final subscriptionNotifierProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
      final actor = ref.watch(subscriptionUserProvider);
      final notifier = SubscriptionNotifier(
        ref.watch(secureStoreProvider),
        ref.watch(paymentGatewayProvider),
        () => actor,
      );
      Future.microtask(() {
        if (notifier.mounted) notifier.load();
      });
      return notifier;
    });
final paymentGatewayProvider = Provider((ref) => PaymentGatewayService());
