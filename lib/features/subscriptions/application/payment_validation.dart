/// Faithful port of payment-validation.ts.
library;

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
