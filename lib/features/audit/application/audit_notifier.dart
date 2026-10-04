import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../dashboard/application/dashboard_notifier.dart';
import '../../iam/application/auth_notifier.dart';
import '../../iam/domain/user.dart';
import '../../patient/domain/patient.dart';
import '../../patient/infrastructure/patient_api.dart';
import '../domain/audit_log.dart';
import '../domain/audit_rules.dart';
import '../infrastructure/audit_api.dart';
import '../infrastructure/audit_pdf_saver.dart';

String describeAuditError(Object e) =>
    e is FormatException ? e.message : describeDioError(e);

class AuditState {
  const AuditState({
    this.logs = const [],
    this.loading = false,
    this.error,
    this.selectedPatientId,
    this.page = 0,
    this.totalElements,
    this.totalPages,
    this.last = true,
    this.hasLoaded = false,
    this.exporting = false,
    this.exportNotice,
  });
  final List<AuditLog> logs;
  final bool loading, last, hasLoaded, exporting;
  final String? error, selectedPatientId, exportNotice;
  final int page;
  final int? totalElements, totalPages;

  AuditState copyWith({
    List<AuditLog>? logs,
    bool? loading,
    String? error,
    bool clearError = false,
    bool? exporting,
    String? exportNotice,
    bool clearExportNotice = false,
  }) => AuditState(
    logs: logs ?? this.logs,
    loading: loading ?? this.loading,
    error: clearError ? null : error ?? this.error,
    selectedPatientId: selectedPatientId,
    page: page,
    totalElements: totalElements,
    totalPages: totalPages,
    last: last,
    hasLoaded: hasLoaded,
    exporting: exporting ?? this.exporting,
    exportNotice: clearExportNotice ? null : exportNotice ?? this.exportNotice,
  );
}

class AuditNotifier extends StateNotifier<AuditState> {
  AuditNotifier(this._api, this._user, this._savePdf, {this.onExportConfirmed})
    : super(const AuditState());
  final AuditApi _api;
  final User? Function() _user;
  final AuditPdfSaver _savePdf;
  final void Function()? onExportConfirmed;
  int _request = 0;
  Future<void>? _loading;
  String? _loadingScope;
  Uint8List? _pdf;
  String? _pdfPatientId;
  bool get hasPendingPdf => _pdf != null;

  User _actor() {
    final actor = _user();
    if (!AuditRules.canRead(actor)) {
      throw const FormatException(
        'Solo Doctor o Admin pueden consultar Auditoría.',
      );
    }
    return actor!;
  }

  bool _sameActor(User actor) {
    final current = _user();
    return mounted &&
        AuditRules.canRead(current) &&
        current!.id == actor.id &&
        current.username == actor.username;
  }

  bool _exportActorIsCurrent(User actor) {
    if (_sameActor(actor)) return true;
    _pdf = null;
    if (mounted) {
      state = const AuditState(error: 'La sesión cambió. Recarga Auditoría.');
    }
    return false;
  }

  Future<void> load() => _query(null, 0);
  Future<void> loadForPatient(String id) => _query(id, 0);
  Future<void> reload() => _query(state.selectedPatientId, state.page);
  Future<void> loadPage(int page) {
    if (state.selectedPatientId != null ||
        page < 0 ||
        state.totalPages == null ||
        page >= state.totalPages!) {
      state = state.copyWith(
        error: 'Selecciona una página disponible de la auditoría general.',
      );
      return Future.value();
    }
    return _query(null, page);
  }

  Future<void> _query(String? rawId, int page) {
    try {
      final actor = _actor();
      final id = rawId == null ? null : AuditRules.id(rawId);
      AuditRules.pagination(page, 100);
      if (state.exporting &&
          (id != state.selectedPatientId || page != state.page)) {
        throw const FormatException(
          'Espera a que termine la exportación antes de cambiar el filtro.',
        );
      }
      final scope = '${id ?? 'all'}:$page';
      if (_loading != null && _loadingScope == scope) return _loading!;
      final request = ++_request;
      _loadingScope = scope;
      _loading = _read(actor, id, page, request);
      return _loading!;
    } catch (e) {
      state = AuditRules.canRead(_user())
          ? state.copyWith(error: describeAuditError(e))
          : AuditState(error: describeAuditError(e));
      return Future.value();
    }
  }

  Future<void> _read(User actor, String? id, int page, int request) async {
    final sameScope = state.selectedPatientId == id && state.page == page;
    if (state.selectedPatientId != id) {
      _pdf = null;
      _pdfPatientId = null;
    }
    state = AuditState(
      logs: sameScope ? state.logs : const [],
      hasLoaded: sameScope && state.hasLoaded,
      loading: true,
      selectedPatientId: id,
      page: page,
      totalElements: sameScope ? state.totalElements : null,
      totalPages: sameScope ? state.totalPages : null,
      last: sameScope ? state.last : true,
      exporting: state.exporting,
      exportNotice: sameScope ? state.exportNotice : null,
    );
    try {
      final List<AuditLog> logs;
      int? total, pages;
      var last = true;
      if (id != null) {
        logs = [...await _api.getPatientTimeline(id)]
          ..sort((a, b) => a.performedAt.compareTo(b.performedAt));
      } else {
        final result = await _api.getPage(page: page);
        logs = [...result.logs]
          ..sort((a, b) => b.performedAt.compareTo(a.performedAt));
        total = result.totalElements;
        pages = result.totalPages;
        last = result.last;
      }
      if (!mounted || request != _request) return;
      if (!_sameActor(actor)) {
        state = const AuditState(error: 'La sesión cambió. Recarga Auditoría.');
        return;
      }
      state = AuditState(
        logs: List.unmodifiable(logs),
        hasLoaded: true,
        selectedPatientId: id,
        page: page,
        totalElements: total,
        totalPages: pages,
        last: last,
        exporting: state.exporting,
        exportNotice: state.exportNotice,
      );
    } catch (e) {
      if (mounted && request == _request) {
        state = _sameActor(actor)
            ? state.copyWith(loading: false, error: describeAuditError(e))
            : const AuditState(error: 'La sesión cambió. Recarga Auditoría.');
      }
    } finally {
      if (request == _request) {
        _loading = null;
        _loadingScope = null;
      }
    }
  }

  Future<bool> exportPdf() async {
    final actor = _actor();
    if (state.exporting) return false;
    if (state.loading || !state.hasLoaded) {
      throw const FormatException(
        'Espera a que se complete la consulta antes de exportar.',
      );
    }
    final id = state.selectedPatientId;
    state = state.copyWith(exporting: true, clearExportNotice: true);
    try {
      if (_pdf == null || _pdfPatientId != id) {
        _pdf = await _api.exportPdf(patientId: id);
        _pdfPatientId = id;
        if (!_exportActorIsCurrent(actor)) {
          return false;
        }
        // El servidor registra la exportación. Actualizar lecturas incluso si se cancela el guardado.
        try {
          onExportConfirmed?.call();
        } catch (_) {}
        await reload();
      }
      if (!_exportActorIsCurrent(actor)) {
        return false;
      }
      final saved = await _savePdf(_pdf!);
      if (!_exportActorIsCurrent(actor)) {
        return false;
      }
      if (saved) _pdf = null;
      state = state.copyWith(
        exportNotice: saved
            ? 'PDF guardado.'
            : 'Guardado cancelado. Puedes elegir un destino de nuevo.',
      );
      return saved;
    } catch (e) {
      if (mounted && _exportActorIsCurrent(actor)) {
        state = state.copyWith(exportNotice: describeAuditError(e));
      }
      return false;
    } finally {
      if (mounted) state = state.copyWith(exporting: false);
    }
  }
}

final auditUserProvider = Provider<User?>(
  (ref) => ref.watch(authNotifierProvider.select((s) => s.user)),
);
final auditPatientsProvider = FutureProvider.autoDispose<List<Patient>>((ref) {
  if (!AuditRules.canRead(ref.watch(auditUserProvider))) {
    throw const FormatException('Sin permiso para consultar Auditoría.');
  }
  return ref.watch(patientApiProvider).getAll();
});
final auditNotifierProvider = StateNotifierProvider<AuditNotifier, AuditState>((
  ref,
) {
  final actor = ref.watch(auditUserProvider);
  final notifier = AuditNotifier(
    ref.watch(auditApiProvider),
    () => actor,
    ref.watch(auditPdfSaverProvider),
    onExportConfirmed: () => ref.invalidate(dashboardNotifierProvider),
  );
  Future.microtask(() {
    if (notifier.mounted) notifier.load();
  });
  return notifier;
});
