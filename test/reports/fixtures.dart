import 'dart:async';

import 'package:nurse_pulse_app/features/audit/domain/audit_log.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/notification/domain/alert.dart';
import 'package:nurse_pulse_app/features/patient/domain/patient.dart';
import 'package:nurse_pulse_app/features/report/application/report_notifier.dart';
import 'package:nurse_pulse_app/features/report/domain/report.dart';
import 'package:nurse_pulse_app/features/report/domain/report_rules.dart';
import 'package:nurse_pulse_app/features/report/infrastructure/report_local_store.dart';
import 'package:nurse_pulse_app/features/sbar/domain/sbar_transfer.dart';
import 'package:nurse_pulse_app/features/vital_sign/domain/vital_sign.dart';

import '../dashboard/fixtures.dart' as dash;

export '../dashboard/fixtures.dart'
    show nurse, doctor, admin, now, patient, vital;

class MemoryReports {
  String? raw;
  int reads = 0, writes = 0;
  Object? readFailure, writeFailure;
  Completer<String?>? reading;
  Completer<void>? writing;
  ReportLocalStore get store => ReportLocalStore(
    read: () async {
      reads++;
      if (readFailure != null) throw readFailure!;
      return reading == null ? raw : reading!.future;
    },
    write: (value) async {
      writes++;
      if (writeFailure != null) throw writeFailure!;
      if (writing != null) await writing!.future;
      raw = value;
    },
  );
}

Report report({
  String id = 'local-test-1',
  String title = 'Reporte ficticio',
  DateTime? date,
}) {
  final period = ReportRules.validate(
    ReportType.general,
    title,
    dash.now,
    dash.now,
  );
  return Report(
    id: id,
    type: ReportType.general,
    title: title,
    generatedBy: 'Equipo clínico',
    startDate: period.start,
    endDate: period.end,
    status: ReportStatus.completed,
    createdAt: date ?? dash.now,
    summary: summary(),
    clinicalConclusion: ReportRules.conclusion(summary()),
  );
}

ReportSummary summary({
  int patients = 0,
  int vitals = 0,
  int events = 0,
  int sbar = 0,
  int alerts = 0,
  int critical = 0,
  int audit = 0,
}) => ReportSummary(
  patients: patients,
  vitalSigns: vitals,
  clinicalEvents: events,
  sbarTransfers: sbar,
  activeAlerts: alerts,
  criticalAlerts: critical,
  auditLogs: audit,
);

class Sources {
  List<Patient> patients = [dash.patient()];
  List<VitalSign> vitals = [];
  List<Alert> alerts = [];
  List<AuditLog> audits = [];
  Map<String, List<SbarTransfer>> transfers = {};
  final calls = <String>[];
  final failures = <String, Object>{};
  Completer<List<Patient>>? patientGate;
  Future<List<T>> _read<T>(String path, List<T> value) async {
    calls.add(path);
    if (failures[path] != null) throw failures[path]!;
    return value;
  }

  ReportSources get sources => ReportSources(
    patients: () async {
      final value = await _read('patients', patients);
      return patientGate == null ? value : patientGate!.future;
    },
    vitals: () => _read('vitals', vitals),
    alerts: () => _read('alerts', alerts),
    audits: () => _read('audits', audits),
    handovers: (id) => _read('sbar/$id', transfers[id] ?? []),
  );
}

class AuditCalls {
  final actions = <String>[];
  final actors = <String>[];
  final descriptions = <String>[];
  Object? failure;
  Completer<void>? gate;
  Future<void> call(
    Report report,
    User actor,
    String action,
    String description,
  ) async {
    actions.add(action);
    actors.add(actor.username);
    descriptions.add(description);
    if (gate != null) await gate!.future;
    if (failure != null) throw failure!;
  }
}

ReportNotifier notifier(
  MemoryReports memory,
  Sources sources, {
  User? actor = dash.doctor,
  User? Function()? user,
  AuditCalls? audit,
  void Function()? onAudited,
}) => ReportNotifier(
  memory.store,
  sources.sources,
  user ?? () => actor,
  (audit ?? AuditCalls()).call,
  clock: () => dash.now,
  onAudited: onAudited,
);
Future<Report> generate(
  ReportNotifier notifier, {
  String type = ReportType.general,
  String title = ' Reporte ficticio ',
  DateTime? from,
  DateTime? to,
}) => notifier.generate(
  type: type,
  title: title,
  startDate: from ?? dash.now,
  endDate: to ?? dash.now,
);
