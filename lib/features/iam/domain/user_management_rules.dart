import 'user.dart';

class UserManagementRules {
  static const roles = [kRoleNurse, kRoleDoctor, kRoleAdmin];
  static bool canManage(User? user) => user?.roles.contains(kRoleAdmin) == true;

  static String id(String value) {
    final text = value.trim(), number = int.tryParse(value.trim());
    if (!RegExp(r'^\d+$').hasMatch(text) || number == null || number <= 0) {
      throw const FormatException(
        'El ID del usuario debe ser un entero positivo.',
      );
    }
    return number.toString();
  }

  static String role(List<String> values) {
    if (values.length != 1 || !roles.contains(values.single.trim())) {
      throw const FormatException('Selecciona un rol Nurse, Doctor o Admin.');
    }
    return values.single.trim();
  }

  static bool isSelf(User actor, User target) =>
      id(actor.id) == id(target.id) ||
      actor.username.trim() == target.username.trim();

  static String label(String role) => switch (role) {
    kRoleAdmin => 'Administrador',
    kRoleDoctor => 'Medicina',
    kRoleNurse => 'Enfermera/o',
    _ => 'Sin rol reconocido',
  };
}
