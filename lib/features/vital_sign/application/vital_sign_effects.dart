import '../../iam/domain/user.dart';
import '../domain/vital_sign.dart';

class VitalSignEffects {
  const VitalSignEffects({required this.audit, required this.createAlert});

  final Future<void> Function(VitalSign, User) audit;
  final Future<void> Function(VitalSign, User) createAlert;

  Future<String?> run(VitalSign sign, User actor) async {
    final warnings = <String>[];

    try {
      await audit(sign, actor);
    } catch (_) {
      warnings.add(
        'Los signos se guardaron, pero no se pudo confirmar su auditoría.',
      );
    }

    if (sign.isHighRisk) {
      try {
        await createAlert(sign, actor);
      } catch (_) {
        warnings.add(
          'Los signos se guardaron, pero no se pudo confirmar la alerta. '
          'Revisa Alertas.',
        );
      }
    }

    return warnings.isEmpty ? null : warnings.join(' ');
  }
}
