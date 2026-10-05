import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/payment_validation.dart';
import '../application/subscription_notifier.dart';
import '../domain/plan.dart';

Future<bool?> showPaymentCheckoutSheet(BuildContext context, Plan plan) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _PaymentCheckoutSheet(plan: plan),
    );

class _PaymentCheckoutSheet extends ConsumerStatefulWidget {
  const _PaymentCheckoutSheet({required this.plan});
  final Plan plan;
  @override
  ConsumerState<_PaymentCheckoutSheet> createState() =>
      _PaymentCheckoutSheetState();
}

class _PaymentCheckoutSheetState extends ConsumerState<_PaymentCheckoutSheet> {
  final _formKey = GlobalKey<FormState>();
  final _cardholder = TextEditingController(),
      _cardNumber = TextEditingController(),
      _expiry = TextEditingController(),
      _cvv = TextEditingController(),
      _email = TextEditingController(),
      _document = TextEditingController();
  BillingDocumentType _documentType = BillingDocumentType.dni;
  bool _submitting = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [
      _cardholder,
      _cardNumber,
      _expiry,
      _cvv,
      _email,
      _document,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pay() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(subscriptionNotifierProvider.notifier)
          .checkout(
            planId: widget.plan.id,
            name: _cardholder.text,
            email: _email.text,
            documentType: _documentType,
            documentNumber: _document.text,
            cardNumber: _cardNumber.text,
            expiry: _expiry.text,
            securityCode: _cvv.text,
          );
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              ref.read(subscriptionNotifierProvider).error ??
              (e is FormatException
                  ? e.message
                  : 'No se pudo completar el pago simulado.'),
        );
      }
    } finally {
      if (mounted) {
        if (ref.read(subscriptionNotifierProvider).receipt != null) {
          for (final c in [
            _cardholder,
            _cardNumber,
            _expiry,
            _cvv,
            _email,
            _document,
          ]) {
            c.clear();
          }
        }
        setState(() => _submitting = false);
      }
    }
  }

  void _format(
    TextEditingController controller,
    String value,
    String Function(String) format,
  ) {
    final formatted = format(value);
    if (value != formatted) {
      controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionNotifierProvider);
    final actor = ref.watch(subscriptionUserProvider);
    final allowed = actor != null && actor.hasKnownRole;
    final busy = _submitting || state.processing;
    final receipt = state.receipt?.request.planId == widget.plan.id
        ? state.receipt
        : null;
    return PopScope(
      canPop: !busy,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Suscribirse a ${widget.plan.name} · USD ${widget.plan.monthlyPrice}/mes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text('Pago simulado. No se realizan cobros reales.'),
                if (!allowed)
                  const Text('Inicia sesión para seleccionar un plan.'),
                const SizedBox(height: 12),
                if (receipt != null) ...[
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 48,
                  ),
                  const Text('Pago simulado aprobado'),
                  Text('Transacción ${receipt.transactionId}'),
                  Text('Tarjeta: •••• ${receipt.request.cardLastFour}'),
                  Text(
                    'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(receipt.paidAt.toLocal())}',
                  ),
                  Text('Total simulado: USD ${receipt.request.amount}'),
                  if (state.pendingPlan != null) ...[
                    Text(state.error ?? 'El plan está pendiente de guardado.'),
                    FilledButton(
                      key: const ValueKey('checkout-save-pending'),
                      onPressed: busy || !allowed
                          ? null
                          : () async {
                              try {
                                await ref
                                    .read(subscriptionNotifierProvider.notifier)
                                    .selectPlan(widget.plan.id);
                              } catch (_) {}
                            },
                      child: const Text('Reintentar guardado del plan'),
                    ),
                  ] else
                    const Text('Plan guardado en este dispositivo.'),
                ] else
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          key: const ValueKey('checkout-name'),
                          controller: _cardholder,
                          enabled: !busy && allowed,
                          decoration: const InputDecoration(
                            labelText: 'Titular de la tarjeta',
                          ),
                          validator: CheckoutRules.name,
                        ),
                        TextFormField(
                          key: const ValueKey('checkout-email'),
                          controller: _email,
                          enabled: !busy && allowed,
                          decoration: const InputDecoration(
                            labelText: 'Email de facturación',
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: CheckoutRules.email,
                        ),
                        DropdownButtonFormField<BillingDocumentType>(
                          key: const ValueKey('checkout-document-type'),
                          initialValue: _documentType,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de documento',
                          ),
                          items: [
                            for (final type in BillingDocumentType.values)
                              DropdownMenuItem(
                                value: type,
                                child: Text(
                                  type == BillingDocumentType.dni
                                      ? 'DNI'
                                      : 'RUC',
                                ),
                              ),
                          ],
                          onChanged: busy || !allowed
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() {
                                      _documentType = value;
                                      _document.clear();
                                    });
                                  }
                                },
                        ),
                        TextFormField(
                          key: const ValueKey('checkout-document'),
                          controller: _document,
                          enabled: !busy && allowed,
                          decoration: InputDecoration(
                            labelText: _documentType == BillingDocumentType.dni
                                ? 'DNI'
                                : 'RUC',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(
                              _documentType == BillingDocumentType.dni ? 8 : 11,
                            ),
                          ],
                          validator: (value) =>
                              CheckoutRules.document(_documentType, value),
                        ),
                        TextFormField(
                          key: const ValueKey('checkout-card'),
                          controller: _cardNumber,
                          enabled: !busy && allowed,
                          decoration: InputDecoration(
                            labelText: 'Número de tarjeta',
                            helperText: detectCardBrand(_cardNumber.text).name
                                .toUpperCase(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => setState(
                            () => _format(_cardNumber, value, formatCardNumber),
                          ),
                          validator: (value) => isValidCardNumber(value ?? '')
                              ? null
                              : 'Número de tarjeta inválido.',
                        ),
                        TextFormField(
                          key: const ValueKey('checkout-expiry'),
                          controller: _expiry,
                          enabled: !busy && allowed,
                          decoration: const InputDecoration(labelText: 'MM/AA'),
                          keyboardType: TextInputType.number,
                          onChanged: (value) =>
                              _format(_expiry, value, formatExpiry),
                          validator: (value) => isValidFutureExpiry(value ?? '')
                              ? null
                              : 'Vencimiento inválido.',
                        ),
                        TextFormField(
                          key: const ValueKey('checkout-cvv'),
                          controller: _cvv,
                          enabled: !busy && allowed,
                          decoration: const InputDecoration(labelText: 'CVV'),
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          validator: (value) => isValidSecurityCode(value ?? '')
                              ? null
                              : 'CVV inválido.',
                        ),
                        if (_error != null)
                          Text(
                            _error!,
                            key: const ValueKey('checkout-error'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        const SizedBox(height: 12),
                        FilledButton(
                          key: const ValueKey('checkout-pay'),
                          onPressed: busy || !allowed ? null : _pay,
                          child: Text(
                            busy
                                ? 'Procesando…'
                                : 'Simular pago USD ${widget.plan.monthlyPrice}',
                          ),
                        ),
                      ],
                    ),
                  ),
                TextButton(
                  key: const ValueKey('checkout-close'),
                  onPressed: busy
                      ? null
                      : () => Navigator.of(context)
                            .pop(receipt != null && state.pendingPlan == null),
                  child: Text(receipt == null ? 'Cancelar' : 'Listo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
