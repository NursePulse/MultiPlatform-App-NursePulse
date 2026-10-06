import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/alert.dart';
import 'alert_notifier.dart';

class AlertInboxState {
  const AlertInboxState({this.alerts = const [], this.notice});
  final List<Alert> alerts;
  final Alert? notice;
}

/// Session-scoped inbox. The first successful snapshot establishes a baseline;
/// historical alerts never generate a burst of new-alert banners.
class AlertInbox extends StateNotifier<AlertInboxState> {
  AlertInbox(this._refresh) : super(const AlertInboxState());
  final Future<void> Function() _refresh;
  final _seen = <String>{};
  bool _initialized = false;
  bool _active = true;
  bool _refreshing = false;

  void receive(List<Alert> alerts) {
    final active = alerts.where((alert) => alert.isActive).toList();
    final fresh = active.where((alert) => !_seen.contains(alert.id)).toList();
    final notice = _initialized && fresh.isNotEmpty
        ? fresh.first
        : active.where((alert) => alert.id == state.notice?.id).firstOrNull;
    _seen.addAll(alerts.map((alert) => alert.id));
    _initialized = true;
    state = AlertInboxState(alerts: active, notice: notice);
  }

  void dismiss() => state = AlertInboxState(alerts: state.alerts);

  void setActive(bool active) {
    final resumed = !_active && active;
    _active = active;
    if (resumed) unawaited(refresh());
  }

  Future<void> refresh() async {
    if (!mounted || !_active || _refreshing) return;
    _refreshing = true;
    try {
      await _refresh();
    } finally {
      _refreshing = false;
    }
  }
}

final alertAppActiveProvider = StateProvider<bool>((ref) => true);

final alertInboxProvider =
    StateNotifierProvider.autoDispose<AlertInbox, AlertInboxState>((ref) {
      // Recreate both the baseline and timer when the authenticated user changes.
      ref.watch(alertUserProvider);
      final inbox = AlertInbox(() async {
        if (!ref.read(alertAppActiveProvider)) return;
        if (!ref.read(alertCanManageProvider)) return;
        final state = ref.read(alertNotifierProvider);
        if (state.loading || state.saving) return;
        await ref
            .read(alertNotifierProvider.notifier)
            .load(quiet: state.loaded);
      });
      ref.listen(alertNotifierProvider, (previous, next) {
        if (next.loaded &&
            (previous?.loaded != true || previous?.alerts != next.alerts)) {
          inbox.receive(next.alerts);
        }
      });
      final snapshot = ref.read(alertNotifierProvider);
      if (snapshot.loaded) inbox.receive(snapshot.alerts);
      Timer? timer;
      void startPolling() {
        timer?.cancel();
        timer = Timer.periodic(const Duration(seconds: 30), (_) {
          unawaited(inbox.refresh());
        });
      }

      startPolling();
      ref.onCancel(() => timer?.cancel());
      ref.onResume(startPolling);
      ref.onDispose(() => timer?.cancel());
      Future.microtask(inbox.refresh);
      return inbox;
    });
