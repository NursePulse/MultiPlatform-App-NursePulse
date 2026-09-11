import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/payment.dart';
import '../domain/plan.dart';

/// Fakes a 1200ms network round-trip, mirroring payment-gateway.service.ts.
/// There is no real payment backend — this never actually charges anything.
class PaymentGatewayService {
  final _random = Random();

  Future<PaymentReceipt> process(PaymentRequest request) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    return PaymentReceipt(
      request: request,
      transactionId: 'PR-${_randomAlphanumeric(10)}',
      paidAt: DateTime.now(),
    );
  }

  String _randomAlphanumeric(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(
      length,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }
}

class SubscriptionNotifier extends StateNotifier<PlanId> {
  SubscriptionNotifier(this._ref) : super(PlanId.essential) {
    _restore();
  }

  final Ref _ref;

  Future<void> _restore() async {
    final stored = await _ref.read(secureStoreProvider).readSubscriptionPlan();
    final match = kPlanCatalog.where((p) => p.id.name == stored).toList();
    if (match.isNotEmpty) state = match.first.id;
  }

  Plan get currentPlan => kPlanCatalog.firstWhere((p) => p.id == state);

  void selectPlan(PlanId planId) {
    state = planId;
    _ref.read(secureStoreProvider).saveSubscriptionPlan(planId.name);
  }
}

final subscriptionNotifierProvider =
    StateNotifierProvider<SubscriptionNotifier, PlanId>(
      (ref) => SubscriptionNotifier(ref),
    );

final paymentGatewayProvider = Provider((ref) => PaymentGatewayService());
