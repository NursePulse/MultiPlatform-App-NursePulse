import '../../iam/domain/user.dart';

class AuditRules {
  static bool canRead(User? user) =>
      user?.roles.any([kRoleDoctor, kRoleAdmin].contains) == true;

  static String id(String value) {
    final text = value.trim(), number = int.tryParse(value.trim());
    if (!RegExp(r'^\d+$').hasMatch(text) || number == null || number <= 0) {
      throw const FormatException(
        'El ID del paciente debe ser un entero positivo.',
      );
    }
    return number.toString();
  }

  static void pagination(int page, int size) {
    if (page < 0 || size < 1 || size > 200) {
      throw const FormatException(
        'La página no puede ser negativa y su tamaño debe estar entre 1 y 200.',
      );
    }
  }

  static bool isPdf(List<int> bytes) =>
      bytes.length >= 12 &&
      String.fromCharCodes(bytes.take(5)) == '%PDF-' &&
      String.fromCharCodes(
        bytes.skip(bytes.length > 1024 ? bytes.length - 1024 : 0),
      ).contains('%%EOF');
}
