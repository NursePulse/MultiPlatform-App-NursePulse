/// Faithful port of payment-validation.ts.
library;

import '../domain/payment.dart';
import '../domain/plan.dart';

enum CardBrand { visa, mastercard, amex, card }

enum BillingDocumentType { dni, ruc }

String onlyDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

String formatCardNumber(String value) {
  final digits = onlyDigits(value);
  final truncated = digits.substring(
    0,
    digits.length > 19 ? 19 : digits.length,
  );
  final buffer = StringBuffer();
  for (var i = 0; i < truncated.length; i++) {
    buffer.write(truncated[i]);
    final remaining = truncated.length - i - 1;
    if ((i + 1) % 4 == 0 && remaining > 0) buffer.write(' ');
  }
  return buffer.toString();
}

String formatExpiry(String value) {
  final digits = onlyDigits(value);
  final truncated = digits.substring(0, digits.length > 4 ? 4 : digits.length);
  if (truncated.length > 2) {
    return '${truncated.substring(0, 2)}/${truncated.substring(2)}';
  }
  return truncated;
}

CardBrand detectCardBrand(String value) {
  final digits = onlyDigits(value);
  if (RegExp(r'^4').hasMatch(digits)) return CardBrand.visa;
  if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(digits)) return CardBrand.mastercard;
  if (RegExp(r'^3[47]').hasMatch(digits)) return CardBrand.amex;
  return CardBrand.card;
}

bool isValidCardNumber(String value) {
  final digits = onlyDigits(value);
  if (digits.length < 13 || digits.length > 19) return false;

  var sum = 0;
  var doubleDigit = false;
  for (var index = digits.length - 1; index >= 0; index--) {
    var digit = int.parse(digits[index]);
    if (doubleDigit) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
    doubleDigit = !doubleDigit;
  }
  return sum % 10 == 0;
}

bool isValidFutureExpiry(String value, [DateTime? today]) {
  final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(value);
  if (match == null) return false;

  final month = int.parse(match.group(1)!);
  final year = 2000 + int.parse(match.group(2)!);
  if (month < 1 || month > 12) return false;

  final now = today ?? DateTime.now();
  final currentYear = now.year;
  final currentMonth = now.month;
  return year > currentYear || (year == currentYear && month >= currentMonth);
}

bool isValidSecurityCode(String value) => RegExp(r'^\d{3,4}$').hasMatch(value);

bool isValidBillingDocument(BillingDocumentType type, String value) {
  final digits = onlyDigits(value);
  return type == BillingDocumentType.dni
      ? digits.length == 8
      : digits.length == 11;
}

class CheckoutRules {
  static String? name(String? value) {
    final text = value?.trim() ?? '';
    return text.length < 3 || text.length > 80
        ? 'El titular debe tener entre 3 y 80 caracteres.'
        : null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    return text.length > 120 ||
            !RegExp(
              r"^(?=.{1,254}$)(?=.{1,64}@)[a-zA-Z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-zA-Z0-9!#$%&'*+/=?^_`{|}~-]+)*@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
            ).hasMatch(text)
        ? 'Ingresa un correo válido de hasta 120 caracteres.'
        : null;
  }

  static String? document(BillingDocumentType type, String? value) =>
      RegExp(r'^\d+$').hasMatch(value?.trim() ?? '') &&
          isValidBillingDocument(type, value!.trim())
      ? null
      : 'El ${type == BillingDocumentType.dni ? 'DNI' : 'RUC'} debe tener ${type == BillingDocumentType.dni ? 8 : 11} dígitos.';
  static PaymentRequest fromForm({
    required Plan plan,
    required String nameValue,
    required String emailValue,
    required BillingDocumentType documentType,
    required String documentNumber,
    required String cardNumber,
    required String expiry,
    required String securityCode,
    DateTime? today,
  }) {
    for (final error in [
      name(nameValue),
      email(emailValue),
      document(documentType, documentNumber),
      isValidCardNumber(cardNumber) ? null : 'Número de tarjeta inválido.',
      isValidFutureExpiry(expiry, today) ? null : 'Vencimiento inválido.',
      isValidSecurityCode(securityCode) ? null : 'CVV inválido.',
    ]) {
      if (error != null) throw FormatException(error);
    }
    final digits = onlyDigits(cardNumber);
    return PaymentRequest(
      planId: plan.id,
      amount: plan.monthlyPrice,
      billingEmail: emailValue.trim(),
      cardholderName: nameValue.trim(),
      cardLastFour: digits.substring(digits.length - 4),
    );
  }
}
