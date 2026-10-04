import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clinical_event/domain/clinical_event.dart';
import '../../clinical_event/infrastructure/clinical_event_api.dart';
import '../../notification/domain/alert.dart';
import '../../notification/infrastructure/alert_api.dart';
import '../../vital_sign/domain/vital_sign.dart';
import '../../vital_sign/infrastructure/vital_sign_api.dart';
import '../domain/patient.dart';
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

final patientDetailProvider = FutureProvider.autoDispose
    .family<Patient, String>(
      (ref, id) => ref.watch(patientApiProvider).getById(id),
    );

final patientHistoryProvider = FutureProvider.autoDispose
    .family<PatientHistory, String>((ref, id) async {
      final results = await Future.wait<Object>([
        ref.watch(vitalSignApiProvider).getByPatientId(id),
        ref.watch(clinicalEventApiProvider).getByPatientId(id),
        ref.watch(alertApiProvider).getByPatientId(id),
      ]);

      final vitals = [...results[0] as List<VitalSign>]
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

      final events = [...results[1] as List<ClinicalEvent>]
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

      return PatientHistory(
        vitals: vitals,
        events: events,
        alerts: results[2] as List<Alert>,
      );
    });
