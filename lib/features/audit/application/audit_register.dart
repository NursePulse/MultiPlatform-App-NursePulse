import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../iam/application/auth_notifier.dart';
import '../infrastructure/audit_api.dart';

const _defaultActor = 'Equipo clínico';

/// Registers a clinical write action in the audit trail, mirroring
/// audit.store.ts's register(). Failures must not interrupt the clinical
/// operation that originated the entry, so errors are swallowed.
Future<void> registerAudit(
  Ref ref, {
  required String entityType,
  required String entityId,
  required String actionType,
  String? patientId,
}) async {
  try {
    await ref
        .read(auditApiProvider)
        .create(
          entityType: entityType,
          entityId: entityId,
          actionType: actionType,
          performedBy:
              ref.read(authNotifierProvider).user?.username ?? _defaultActor,
          patientId: patientId,
        );
  } catch (_) {
    // The backend remains the source of truth; audit persistence is best-effort.
  }
}
