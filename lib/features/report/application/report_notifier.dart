import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../audit/application/audit_notifier.dart';
import '../../audit/domain/audit_log.dart';
import '../../audit/infrastructure/audit_api.dart';
import '../../dashboard/application/dashboard_notifier.dart';
import '../../iam/application/auth_notifier.dart';
import '../../iam/domain/user.dart';
import '../../notification/domain/alert.dart';
import '../../notification/infrastructure/alert_api.dart';
import '../../patient/domain/patient.dart';
import '../../patient/infrastructure/patient_api.dart';
import '../../sbar/domain/sbar_transfer.dart';
import '../../sbar/infrastructure/sbar_api.dart';
import '../../vital_sign/domain/vital_sign.dart';
import '../../vital_sign/infrastructure/vital_sign_api.dart';
import '../domain/report.dart';
import '../domain/report_rules.dart';
import '../infrastructure/report_local_store.dart';

String describeReportError(Object error) =>
    error is FormatException ? error.message : describeDioError(error);

class ReportSources {
  const ReportSources({
    required this.patients,
    required this.vitals,
    required this.handovers,
    required this.alerts,
    required this.audits,
  });
  final Future<List<Patient>> Function() patients;
  final Future<List<VitalSign>> Function() vitals;
  final Future<List<SbarTransfer>> Function(String patientId) handovers;
  final Future<List<Alert>> Function() alerts;
  final Future<List<AuditLog>> Function() audits;
}

typedef ReportAudit = Future<void> Function(
  Report report,
  User actor,
  String action,
  String description,
);

class ReportState {
  const ReportState({
    this.reports = const [],
    this.loading = false,
    this.generating = false,
    this.error,
    this.warning,
  });
  final List<Report> reports;
  final bool loading, generating;
  final String? error, warning;
}

class ReportNotifier extends StateNotifier<ReportState> {
  ReportNotifier(
    this._store,
    this._sources,
    this._user,
    this._audit, {
    DateTime Function()? clock,
    String Function()? id,
    this.onAudited,
  }) : _clock = clock ?? DateTime.now,
       _id = id ?? newReportId,
       super(const ReportState());
  final ReportLocalStore _store;
  final ReportSources _sources;
  final User? Function() _user;
  final ReportAudit _audit;
  final DateTime Function() _clock;
  final String Function() _id;
  final void Function()? onAudited;
  Future<void>? _loading;

  User _actor() {
    final actor = _user();
    if (!ReportRules.canGenerate(actor)) {
      throw const FormatException(
        'Solo Doctor o Admin pueden consultar y generar reportes.',
      );
    }
    return actor!;
  }

  bool _sameActor(User actor) {
    final current = _user();
    return mounted &&
        ReportRules.canGenerate(current) &&
        current!.id == actor.id &&
        current.username == actor.username;
  }

  void _check(User actor) {
    if (!_sameActor(actor)) {
      throw const FormatException('La sesión cambió. Recarga Reportes.');
    }
  }

  Future<void> load() {
    if (state.generating) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    User? actor;
    try {
      actor = _actor();
      state = ReportState(
        reports: state.reports,
        loading: true,
        warning: state.warning,
      );
      final reports = await _store.getAll();
      _check(actor);
      state = ReportState(
        reports: List.unmodifiable(reports),
        warning: state.warning,
      );
    } catch (e) {
      if (mounted) {
        state = ReportState(
          reports: actor != null && _sameActor(actor)
              ? state.reports
              : const [],
          error: e is FormatException
              ? e.message
              : 'No se pudieron leer los reportes guardados. Reintenta.',
        );
      }
    }
  }

  Future<Report> generate({
    required String type,
    required String title,
    required DateTime? startDate,
    required DateTime? endDate,
  }) async {
    final actor = _actor();
    final period = ReportRules.validate(type, title, startDate, endDate);
    if (state.generating || state.loading) {
      throw const FormatException(
        'Espera a que termine la operación en curso.',
      );
    }
    state = ReportState(reports: state.reports, generating: true);
    try {
      // Pacientes es obligatorio. Los demás recursos conservan el fallback a cero de la web.
      final patients = await _sources.patients();
      _check(actor);
      Future<List<T>> optional<T>(Future<List<T>> Function() read) async {
        try {
          return await read();
        } catch (_) {
          return <T>[];
        }
      }

      final vitalsFuture = optional(_sources.vitals);
      final alertsFuture = optional(_sources.alerts);
      final auditsFuture = optional(_sources.audits);
      final handoversFuture = Future.wait(
        patients.map((p) => optional(() => _sources.handovers(p.id))),
      );
      final vitals = await vitalsFuture;
      final alerts = await alertsFuture;
      final audits = await auditsFuture;
      final handovers = (await handoversFuture).expand((group) => group);
      _check(actor);
      final auditsInPeriod = audits
          .where((a) => period.contains(a.performedAt))
          .toList();
      final alertsInPeriod = alerts
          .where(
            (a) => a.triggeredAt == null || period.contains(a.triggeredAt!),
          )
          .toList();
      final summary = ReportSummary(
        patients: patients.length,
        vitalSigns: vitals.where((v) => period.contains(v.recordedAt)).length,
        clinicalEvents: auditsInPeriod
            .where((a) => a.entityType == 'CLINICAL_EVENT')
            .length,
        sbarTransfers: handovers
            .where(
              (s) =>
                  s.transferredAt == null || period.contains(s.transferredAt!),
            )
            .length,
        activeAlerts: alertsInPeriod.where((a) => a.isActive).length,
        criticalAlerts: alertsInPeriod
            .where((a) => a.isActive && a.isCritical)
            .length,
        auditLogs: auditsInPeriod.length,
      );
      final created = Report(
        id: _id(),
        type: type,
        title: title.trim(),
        generatedBy: 'Equipo clínico',
        startDate: period.start,
        endDate: period.end,
        status: ReportStatus.completed,
        createdAt: _clock(),
        summary: summary,
        clinicalConclusion: ReportRules.conclusion(summary),
      );
      final List<Report> reports;
      try {
        reports = await _store.add(created);
      } catch (_) {
        throw const FormatException(
          'No se pudo guardar el reporte en este dispositivo. Reintenta.',
        );
      }
      // El documento ya es persistente. Ninguna falla posterior habilita repetir su generación.
      if (!_sameActor(actor)) return created;
      state = ReportState(reports: reports, generating: true);
      var auditFailed = false;
      for (final entry in [
        ('VIEW', 'Generó reporte: ${created.title}'),
        (
          'UPDATE',
          'Transacción: consolidación de datos clínicos conectados al backend - reporte - auditoría',
        ),
      ]) {
        if (!_sameActor(actor)) break;
        try {
          await _audit(created, actor, entry.$1, entry.$2);
        } catch (_) {
          auditFailed = true;
        }
      }
      if (_sameActor(actor)) {
        state = ReportState(
          reports: state.reports,
          warning: auditFailed
              ? 'Reporte guardado. No se pudo completar su auditoría; no vuelvas a generarlo por este aviso.'
              : null,
        );
        try {
          onAudited?.call();
        } catch (_) {}
      }
      return created;
    } catch (e) {
      if (mounted) {
        state = ReportState(
          reports: _sameActor(actor) ? state.reports : const [],
          error: describeReportError(e),
        );
      }
      rethrow;
    } finally {
      if (mounted && state.generating) {
        state = ReportState(
          reports: _sameActor(actor) ? state.reports : const [],
          warning: state.warning,
        );
      }
    }
  }
}

final reportUserProvider = Provider<User?>(
  (ref) => ref.watch(authNotifierProvider.select((s) => s.user)),
);
final reportClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
final reportNotifierProvider =
    StateNotifierProvider<ReportNotifier, ReportState>((ref) {
      final actor = ref.watch(reportUserProvider);
      final audit = ref.watch(auditApiProvider);
      final notifier = ReportNotifier(
        ref.watch(reportLocalStoreProvider),
        ReportSources(
          patients: ref.watch(patientApiProvider).getAll,
          vitals: ref.watch(vitalSignApiProvider).getAll,
          handovers: ref.watch(sbarApiProvider).getByPatientId,
          alerts: ref.watch(alertApiProvider).getAll,
          audits: audit.getAll,
        ),
        () => actor,
        (report, actor, action, description) async {
          await audit.create(
            entityType: 'AUDIT_LOG',
            entityId: report.id,
            actionType: action,
            performedBy: actor.username,
            metadata: {'description': description, 'source': 'frontend'},
          );
        },
        clock: ref.watch(reportClockProvider),
        onAudited: () {
          ref.invalidate(auditNotifierProvider);
          ref.invalidate(dashboardNotifierProvider);
        },
      );
      Future.microtask(() {
        if (notifier.mounted) notifier.load();
      });
      return notifier;
    });
