import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/user.dart';

class ViewModeNotifier extends StateNotifier<ViewMode> {
  ViewModeNotifier(this._ref) : super(ViewMode.nurse);

  final Ref _ref;

  // Deliberately does not self-restore from secure storage on construction:
  // AuthNotifier is the single source of truth for this value, setting it
  // synchronously (within the same restore/sign-in flow) from the real
  // authenticated user's role. A second, independent async read from storage
  // here raced with that assignment and could overwrite it with a stale
  // value, since flutter_secure_storage is async (unlike the Angular app's
  // synchronous localStorage, which never had this race).

  void setMode(ViewMode mode) {
    state = mode;
    _ref.read(secureStoreProvider).saveViewMode(mode.storageValue);
  }

  void cycle() => setMode(state.next);
}

final viewModeProvider = StateNotifierProvider<ViewModeNotifier, ViewMode>(
  (ref) => ViewModeNotifier(ref),
);
