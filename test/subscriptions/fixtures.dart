import 'dart:async';

import 'package:nurse_pulse_app/core/storage/secure_store.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/subscriptions/application/payment_validation.dart';
import 'package:nurse_pulse_app/features/subscriptions/application/subscription_notifier.dart';
import 'package:nurse_pulse_app/features/subscriptions/domain/payment.dart';
import 'package:nurse_pulse_app/features/subscriptions/domain/plan.dart';

import '../dashboard/fixtures.dart';

export '../dashboard/fixtures.dart' show nurse, doctor, admin, now;

class PlanStore extends SecureStore {
  String? stored;
  int reads = 0, writes = 0;
  Object? readFailure, writeFailure;
  Completer<String?>? reading;
  Completer<void>? writing;
  @override
  Future<String?> readSubscriptionPlan() async {
    reads++;
    if (readFailure != null) throw readFailure!;
    return reading == null ? stored : reading!.future;
  }

  @override
  Future<void> saveSubscriptionPlan(String planId) async {
    writes++;
    if (writeFailure != null) throw writeFailure!;
    if (writing != null) await writing!.future;
    stored = planId;
  }
}

class Gateway extends PaymentGatewayService {
  int calls = 0;
  PaymentRequest? request;
  Object? failure;
  Completer<PaymentReceipt>? gate;
  PaymentReceipt Function(PaymentRequest)? result;
  @override
  Future<PaymentReceipt> process(PaymentRequest request) async {
    calls++;
    this.request = request;
    if (failure != null) throw failure!;
    return gate == null
        ? result?.call(request) ??
              PaymentReceipt(
                request: request,
                transactionId: 'PR-FICTICIO',
                paidAt: now,
              )
        : gate!.future;
  }
}

SubscriptionNotifier notifier(
  PlanStore store,
  Gateway gateway, {
  User? actor = admin,
  User? Function()? user,
}) => SubscriptionNotifier(store, gateway, user ?? () => actor);

// Número de prueba publicado en el propio formulario web; ninguna tarjeta real.
const demoCard = '4242 4242 4242 4242';
Future<PaymentReceipt> pay(
  SubscriptionNotifier notifier, {
  PlanId plan = PlanId.professional,
  String name = ' Titular ficticio ',
  String email = ' billing@example.test ',
  BillingDocumentType documentType = BillingDocumentType.dni,
  String document = '00000001',
  String card = demoCard,
  String expiry = '10/26',
  String cvv = '123',
}) => notifier.checkout(
  planId: plan,
  name: name,
  email: email,
  documentType: documentType,
  documentNumber: document,
  cardNumber: card,
  expiry: expiry,
  securityCode: cvv,
  today: now,
);
