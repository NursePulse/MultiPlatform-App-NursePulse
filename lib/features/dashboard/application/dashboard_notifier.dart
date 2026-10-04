import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../iam/application/auth_notifier.dart';
import '../../iam/domain/user.dart';
import '../domain/dashboard_rules.dart';
import '../domain/dashboard_summary.dart';
import '../infrastructure/dashboard_api.dart';

class DashboardState {
  const DashboardState({
    this.data,
    this.summary,
    this.loading = false,
    this.error,
  });
  final DashboardData? data;
  final DashboardSummary? summary;
  final bool loading;
  final String? error;
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier(this._api, this._user, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(const DashboardState());
  final DashboardApi _api;
  final User? Function() _user;
  final DateTime Function() _clock;
  Future<void>? _pending;

  Future<void> load() {
    if (_pending != null) return _pending!;
    final operation = _load();
    _pending = operation.whenComplete(() => _pending = null);
    return _pending!;
  }

  Future<void> _load() async {
    final actor = _user();
    if (!DashboardRules.canRead(actor?.roles ?? const [])) {
      state = const DashboardState(
        error: 'No tienes permiso para consultar el Dashboard.',
      );
      return;
    }
    state = DashboardState(
      data: state.data,
      summary: state.summary,
      loading: true,
    );
    try {
      final data = await _api.getData(
        includeAudit: DashboardRules.canReadAudit(actor!.roles),
      );
      if (!mounted) return;
      final current = _user();
      if (current == null ||
          current.id != actor.id ||
          current.username != actor.username ||
          current.primaryRole != actor.primaryRole ||
          !DashboardRules.canRead(current.roles) ||
          DashboardRules.canReadAudit(current.roles) !=
              DashboardRules.canReadAudit(actor.roles)) {
        state = const DashboardState(
          error: 'La sesión cambió. Recarga el Dashboard.',
        );
        return;
      }
      state = DashboardState(
        data: data,
        summary: DashboardRules.summarize(data, _clock()),
      );
    } catch (e) {
      if (mounted) {
        state = DashboardState(
          data: state.data,
          summary: state.summary,
          error: e is FormatException ? e.message : describeDioError(e),
        );
      }
    }
  }
}

final dashboardUserProvider = Provider<User?>(
  (ref) => ref.watch(authNotifierProvider.select((s) => s.user)),
);
final dashboardClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
final dashboardNotifierProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
      final user = ref.watch(dashboardUserProvider);
      final notifier = DashboardNotifier(
        ref.watch(dashboardApiProvider),
        () => user,
        clock: ref.watch(dashboardClockProvider),
      );
      Future.microtask(() {
        if (notifier.mounted) notifier.load();
      });
      return notifier;
    });
