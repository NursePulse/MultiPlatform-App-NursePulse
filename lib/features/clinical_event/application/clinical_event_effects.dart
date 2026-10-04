import '../../iam/domain/user.dart';
import '../domain/clinical_event.dart';
import '../domain/clinical_event_rules.dart';

class ClinicalEventEffects {
  const ClinicalEventEffects({required this.audit, required this.createAlert});

  final Future<void> Function(ClinicalEvent, User) audit;
  final Future<void> Function(ClinicalEvent, User) createAlert;

  Future<String?> run(ClinicalEvent event, User actor) async {
    final warnings = <String>[];
    try {
      await audit(event, actor);
    } catch (_) {
      warnings.add(
        'El evento se guardó, pero no se pudo confirmar su auditoría.',
      );
    }
    if (ClinicalEventRules.needsAlert(event)) {
      try {
        await createAlert(event, actor);
      } catch (_) {
        warnings.add(
          'El evento se guardó, pero no se pudo confirmar la alerta. Revisa Alertas.',
        );
      }
    }
    return warnings.isEmpty ? null : warnings.join(' ');
  }
}
