import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/session_events.dart';
import '../../../core/storage/secure_store.dart';
import '../domain/user.dart';
import '../infrastructure/iam_api.dart';
import 'view_mode_notifier.dart';

class AuthState {
  const AuthState({
    this.user,
    this.token,
    this.loading = false,
    this.restoring = true,
  });

  final User? user;
  final String? token;
  final bool loading;

  /// True while the session is being restored from secure storage on app
  /// start — the router waits for this before deciding where to send guests.
  final bool restoring;

  bool get isAuthenticated => user != null && token != null;

  AuthState copyWith({
    User? user,
    String? token,
    bool? loading,
    bool? restoring,
    bool clear = false,
  }) {
    if (clear) {
      return AuthState(loading: loading ?? false, restoring: false);
    }
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      loading: loading ?? this.loading,
      restoring: restoring ?? this.restoring,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref)
    : _api = _ref.read(authenticationApiProvider),
      _secureStore = _ref.read(secureStoreProvider),
      super(const AuthState()) {
    _ref.listen<int>(unauthorizedEventProvider, (previous, next) {
      if (previous != null && state.isAuthenticated) {
        signOut();
      }
    });
    _restore();
  }

  final Ref _ref;
  final AuthenticationApi _api;
  final SecureStore _secureStore;

  Future<void> _restore() async {
    final token = await _secureStore.readToken();
    final userJson = await _secureStore.readUser();
    if (token != null && userJson != null) {
      final user = User.fromJson(userJson);
      state = state.copyWith(user: user, token: token, restoring: false);
      // The persisted view mode may be stale (e.g. an admin re-assigned this
      // user's role in another session) — always resync it to the real role
      // on restore, same as signIn() does.
      final mode = ViewModeX.fromRole(user.primaryRole);
      _ref.read(viewModeProvider.notifier).setMode(mode);
    } else {
      state = state.copyWith(restoring: false);
    }
  }

  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(loading: true);
    try {
      final session = await _api.signIn(username: username, password: password);
      await _secureStore.saveSession(
        token: session.token,
        user: session.user.toJson(),
      );
      final mode = ViewModeX.fromRole(session.user.primaryRole);
      await _secureStore.saveViewMode(mode.storageValue);
      _ref.read(viewModeProvider.notifier).setMode(mode);
      state = state.copyWith(
        user: session.user,
        token: session.token,
        loading: false,
      );
    } catch (_) {
      state = state.copyWith(loading: false);
      rethrow;
    }
  }

  Future<void> signUp({
    required String username,
    required String password,
    required String role,
  }) async {
    state = state.copyWith(loading: true);
    try {
      await _api.signUp(username: username, password: password, role: role);
      state = state.copyWith(loading: false);
    } catch (_) {
      state = state.copyWith(loading: false);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _secureStore.clearSession();
    await _secureStore.clearViewMode();
    _ref.read(viewModeProvider.notifier).setMode(ViewMode.nurse);
    state = state.copyWith(clear: true);
  }

  bool hasAnyRole(List<String> roles) => state.user?.hasAnyRole(roles) ?? false;
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);
