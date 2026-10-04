import '../../iam/domain/user.dart';
import 'sbar_transfer.dart';

class SbarRules {
  SbarRules._();
  static bool canRead(List<String> roles) =>
      roles.any([kRoleNurse, kRoleDoctor, kRoleAdmin].contains);
  static bool canManage(List<String> roles) =>
      roles.any([kRoleNurse, kRoleAdmin].contains);

  static String? id(String? value, String label) {
    final text = value?.trim() ?? '';
    final number = int.tryParse(text);
    return RegExp(r'^[0-9]+$').hasMatch(text) && number != null && number > 0
        ? null
        : 'Selecciona $label válido.';
  }

  static String? section(String? value, String label) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Completa $label.';
    return text.length < 8 || text.length > 1000
        ? '$label debe tener entre 8 y 1000 caracteres.'
        : null;
  }

  static List<User> receivers(Iterable<User> users, String? actorId) =>
      users
          .where(
            (u) =>
                u.roles.contains(kRoleNurse) &&
                u.id != actorId &&
                id(u.id, 'un receptor') == null,
          )
          .toList()
        ..sort((a, b) => a.username.compareTo(b.username));

  static RegisterSbarCommand validate(
    RegisterSbarCommand c, {
    required String actorId,
  }) {
    for (final error in [
      id(c.patientId, 'un paciente'),
      id(c.targetNurseId, 'un receptor'),
      section(c.situation, 'Situación'),
      section(c.background, 'Antecedentes'),
      section(c.assessment, 'Evaluación'),
      section(c.recommendation, 'Recomendación'),
    ]) {
      if (error != null) throw FormatException(error);
    }
    final target = int.parse(c.targetNurseId!.trim()).toString();
    if (target == actorId) {
      throw const FormatException(
        'Selecciona un receptor distinto del usuario actual.',
      );
    }
    final title = c.title.trim();
    if (title.isEmpty || title.length > 255) {
      throw const FormatException(
        'El título debe tener entre 1 y 255 caracteres.',
      );
    }
    return RegisterSbarCommand(
      patientId: int.parse(c.patientId.trim()).toString(),
      targetNurseId: target,
      title: title,
      situation: c.situation.trim(),
      background: c.background.trim(),
      assessment: c.assessment.trim(),
      recommendation: c.recommendation.trim(),
    );
  }
}
