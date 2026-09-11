import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/payment_validation.dart';
import '../application/subscription_notifier.dart';
import '../domain/payment.dart';
import '../domain/plan.dart';

Future<bool?> showPaymentCheckoutSheet(BuildContext context, Plan plan) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _PaymentCheckoutSheet(plan: plan),
  );
}

class _PaymentCheckoutSheet extends ConsumerStatefulWidget {
  const _PaymentCheckoutSheet({required this.plan});

  final Plan plan;

  @override
  ConsumerState<_PaymentCheckoutSheet> createState() =>
      _PaymentCheckoutSheetState();
}

class _PaymentCheckoutSheetState extends ConsumerState<_PaymentCheckoutSheet> {
  final _formKey = GlobalKey<FormState>();
  final _cardholder = TextEditingController();
  final _cardNumber = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  final _email = TextEditingController();
  bool _submitting = false;
  String? _error;
  PaymentReceipt? _receipt;

  @override
  void dispose() {
    for (final c in [_cardholder, _cardNumber, _expiry, _cvv, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final receipt = await ref
          .read(paymentGatewayProvider)
          .process(
            PaymentRequest(
              planId: widget.plan.id,
              amount: widget.plan.monthlyPrice,
              billingEmail: _email.text.trim(),
              cardholderName: _cardholder.text.trim(),
              cardLastFour: onlyDigits(_cardNumber.text).length >= 4
                  ? onlyDigits(_cardNumber.text)
                        .substring(onlyDigits(_cardNumber.text).length - 4)
                  : onlyDigits(_cardNumber.text),
            ),
          );
      ref
          .read(subscriptionNotifierProvider.notifier)
          .selectPlan(widget.plan.id);
      setState(() => _receipt = receipt);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_receipt != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Pago aprobado',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text('Transacción ${_receipt!.transactionId}'),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Listo'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Suscribirse a ${widget.plan.name} · \$${widget.plan.monthlyPrice}/mes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(
                  labelText: 'Email de facturación',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => (value == null || !value.contains('@'))
                    ? 'Email inválido'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cardholder,
                decoration: const InputDecoration(
                  labelText: 'Titular de la tarjeta',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Requerido'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cardNumber,
                decoration: const InputDecoration(
                  labelText: 'Número de tarjeta',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final formatted = formatCardNumber(value);
                  if (formatted != value) {
                    _cardNumber.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(
                        offset: formatted.length,
                      ),
                    );
                  }
                },
                validator: (value) => isValidCardNumber(value ?? '')
                    ? null
                    : 'Número de tarjeta inválido',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiry,
                      decoration: const InputDecoration(labelText: 'MM/AA'),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final formatted = formatExpiry(value);
                        if (formatted != value) {
                          _expiry.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                              offset: formatted.length,
                            ),
                          );
                        }
                      },
                      validator: (value) => isValidFutureExpiry(value ?? '')
                          ? null
                          : 'Vencimiento inválido',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _cvv,
                      decoration: const InputDecoration(labelText: 'CVV'),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      validator: (value) => isValidSecurityCode(value ?? '')
                          ? null
                          : 'CVV inválido',
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _pay,
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Pagar \$${widget.plan.monthlyPrice}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
