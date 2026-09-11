import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../domain/user.dart';
import '../infrastructure/iam_api.dart';

class UsersState {
  const UsersState({
    this.users = const [],
    this.roles = const [],
    this.loading = false,
    this.error,
  });

  final List<User> users;
  final List<RoleOption> roles;
  final bool loading;
  final String? error;

  UsersState copyWith({
    List<User>? users,
    List<RoleOption>? roles,
    bool? loading,
    String? error,
  }) => UsersState(
    users: users ?? this.users,
    roles: roles ?? this.roles,
    loading: loading ?? this.loading,
    error: error,
  );
}

class UsersNotifier extends StateNotifier<UsersState> {
  UsersNotifier(this._ref)
    : _usersApi = _ref.read(usersApiProvider),
      _rolesApi = _ref.read(rolesApiProvider),
      super(const UsersState());

  // ignore: unused_field
  final Ref _ref;
  final UsersApi _usersApi;
  final RolesApi _rolesApi;

  /// Users and roles are fetched independently: GET /roles is admin-only,
  /// so a nurse loading this for a receiver dropdown must not lose the user
  /// list just because the roles catalog (only needed for role-assignment
  /// UI) came back 403.
  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final users = await _usersApi.getAll();
      state = state.copyWith(users: users);
    } catch (e) {
      state = state.copyWith(error: describeDioError(e));
    }
    try {
      final roles = await _rolesApi.getAll();
      state = state.copyWith(roles: roles);
    } catch (_) {
      // Role catalog is only needed by the admin role-assignment screen.
    }
    state = state.copyWith(loading: false);
  }

  Future<void> updateRoles(String userId, List<String> roles) async {
    final updated = await _usersApi.updateRoles(userId, roles);
    state = state.copyWith(
      users: [
        for (final user in state.users)
          if (user.id == userId) updated else user,
      ],
    );
  }
}

final usersNotifierProvider = StateNotifierProvider<UsersNotifier, UsersState>(
  (ref) => UsersNotifier(ref),
);
