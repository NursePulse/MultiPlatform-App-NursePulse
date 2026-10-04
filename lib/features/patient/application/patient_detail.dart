import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/domain/dashboard_rules.dart';
import '../../iam/application/auth_notifier.dart';
import '../../clinical_event/domain/clinical_event.dart';
import '../../clinical_event/infrastructure/clinical_event_api.dart';
import '../../notification/domain/alert.dart';
import '../../notification/infrastructure/alert_api.dart';
import '../../vital_sign/domain/vital_sign.dart';
import '../../vital_sign/infrastructure/vital_sign_api.dart';
import '../domain/patient.dart';
import '../domain/patient_monitoring_rules.dart';
import '../infrastructure/patient_api.dart';

class PatientHistory {
  const PatientHistory({
    required this.vitals,
    required this.events,
    required this.alerts,
  });

  final List<VitalSign> vitals;
  final List<ClinicalEvent> events;
  final List<Alert> alerts;
}

final patientMonitoringRolesProvider = Provider<List<String>>(
  (ref) => ref.watch(
    authNotifierProvider.select((s) => s.user?.roles ?? const <String>[]),
  ),
);
final patientMonitoringClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

String _validate(Ref ref, String id) {
  if (!PatientMonitoringRules.canRead(
    ref.watch(patientMonitoringRolesProvider),
  )) {
    throw const FormatException(
      'No tienes permiso para consultar el seguimiento del paciente.',
    );
  }
  return PatientMonitoringRules.id(id);
}

final patientDetailProvider = FutureProvider.autoDispose
    .family<Patient, String>((ref, id) async {
      final validated = _validate(ref, id);
      final patient = await ref.watch(patientApiProvider).getById(validated);
      if (patient.id != validated) {
        throw const FormatException(
          'La API devolvió otro paciente. Recarga el detalle.',
        );
      }
      return patient;
    });

final patientHistoryProvider = FutureProvider.autoDispose
    .family<PatientHistory, String>((ref, id) async {
      final validated = _validate(ref, id);
      final results = await Future.wait<Object>([
        ref.watch(vitalSignApiProvider).getByPatientId(validated),
        ref.watch(clinicalEventApiProvider).getByPatientId(validated),
        ref.watch(alertApiProvider).getByPatientId(validated),
      ]);

      final vitals = [...results[0] as List<VitalSign>]
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

      final events = [...results[1] as List<ClinicalEvent>]
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      final alerts = DashboardRules.sortedAlerts(results[2] as List<Alert>);
      if (vitals.any((v) => v.patientId != validated) ||
          events.any((e) => e.patientId != validated) ||
          alerts.any((a) => a.patientId != validated)) {
        throw const FormatException(
          'El historial contiene datos de otro paciente. Recarga el historial.',
        );
      }

      return PatientHistory(
        vitals: List.unmodifiable(vitals),
        events: List.unmodifiable(events),
        alerts: List.unmodifiable(alerts),
      );
    });
