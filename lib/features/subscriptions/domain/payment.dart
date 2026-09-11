import 'plan.dart';

class PaymentRequest {
  const PaymentRequest({
    required this.planId,
    required this.amount,
    required this.billingEmail,
    required this.cardholderName,
    required this.cardLastFour,
  });

  final PlanId planId;
  final num amount;
  final String billingEmail;
  final String cardholderName;
  final String cardLastFour;
}

class PaymentReceipt {
  const PaymentReceipt({
    required this.request,
    required this.transactionId,
    required this.paidAt,
  });

  final PaymentRequest request;
  final String transactionId;
  final DateTime paidAt;
}
