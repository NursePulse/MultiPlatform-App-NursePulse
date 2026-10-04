import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../dashboard/application/dashboard_notifier.dart';
import '../../patient/application/patient_notifier.dart';
import '../../sbar/application/sbar_notifier.dart';
import '../domain/user.dart';
import '../domain/user_management_rules.dart';
import '../infrastructure/iam_api.dart';
import 'auth_notifier.dart';

String describeUserManagementError(Object error) {
  if (error is FormatException) return error.message;
  if (error is DioException) {
    if (error.response?.statusCode == 422) {
      return 'No puedes cambiar tu propio rol.';
    }
    if (error.response?.statusCode == 404) {
      return 'El usuario o rol ya no está disponible. Actualiza el listado.';
    }
  }
  return describeDioError(error);
}

class UsersState {
  const UsersState({
    this.users = const [],
    this.loading = false,
    this.saving = false,
    this.savingId,
    this.error,
    this.warning,
    this.updatedUserId,
    this.unverifiedIds = const {},
  });
  final List<User> users;
  final bool loading, saving;
  final String? savingId, error, warning, updatedUserId;
  final Set<String> unverifiedIds;
}

class UsersNotifier extends StateNotifier<UsersState> {
  UsersNotifier(this._api, this._user, {this.onChanged})
    : super(const UsersState());
  final UsersApi _api;
  final User? Function() _user;
  final void Function()? onChanged;
  Future<void>? _loading;

  User _actor() {
    final actor = _user();
    if (!UserManagementRules.canManage(actor)) {
      throw const FormatException('Solo Admin puede administrar usuarios.');
    }
    UserManagementRules.id(actor!.id);
    return actor;
  }

  bool _sameActor(User actor) {
    final current = _user();
    return mounted &&
        UserManagementRules.canManage(current) &&
        current!.id == actor.id &&
        current.username == actor.username;
  }

  Future<void> load() {
    if (state.saving) return Future.value();
    if (_loading != null) return _loading!;
    _loading = _load().whenComplete(() => _loading = null);
    return _loading!;
  }

  Future<void> _load() async {
    User? actor;
    try {
      actor = _actor();
      state = UsersState(
        users: state.users,
        loading: true,
        unverifiedIds: state.unverifiedIds,
        warning: state.warning,
      );
      final users = (await _api.getAll()).map((user) {
        final id = UserManagementRules.id(user.id);
        if (user.username.trim().isEmpty) {
          throw const FormatException('La API devolvió un usuario sin nombre.');
        }
        return User(
          id: id,
          username: user.username,
          roles: user.roles,
          firstName: user.firstName,
          lastName: user.lastName,
        );
      }).toList();
      if (!_sameActor(actor)) {
        if (mounted) {
          state = const UsersState(
            error: 'La sesión cambió. Recarga el listado.',
          );
        }
        return;
      }
      if (users.map((u) => u.id).toSet().length != users.length) {
        throw const FormatException('La lista contiene usuarios duplicados.');
      }
      state = UsersState(users: List.unmodifiable(users));
    } catch (e) {
      if (mounted) {
        state = UsersState(
          users: actor != null && _sameActor(actor) ? state.users : const [],
          error: describeUserManagementError(e),
          warning: state.warning,
          unverifiedIds: state.unverifiedIds,
        );
      }
    }
  }

  Future<void> updateRoles(String userId, List<String> roles) async {
    final actor = _actor();
    final id = UserManagementRules.id(userId),
        role = UserManagementRules.role(roles);
    final target = state.users.where((u) => u.id == id).firstOrNull;
    if (target == null) {
      throw const FormatException(
        'El usuario ya no está disponible. Actualiza el listado.',
      );
    }
    if (UserManagementRules.isSelf(actor, target)) {
      throw const FormatException('No puedes cambiar tu propio rol.');
    }
    if (state.saving || state.loading) {
      throw const FormatException(
        'Espera a que termine la operación en curso.',
      );
    }
    if (state.unverifiedIds.contains(id)) {
      throw const FormatException(
        'El cambio fue confirmado. Actualiza el listado antes de modificarlo de nuevo.',
      );
    }
    if (target.primaryRole == role) return;
    state = UsersState(
      users: state.users,
      saving: true,
      savingId: id,
      unverifiedIds: state.unverifiedIds,
    );
    try {
      final latest = await _api.getById(id);
      if (!_sameActor(actor)) {
        throw const FormatException(
          'La sesión cambió. Inicia la operación de nuevo.',
        );
      }
      if (UserManagementRules.isSelf(actor, latest)) {
        throw const FormatException('No puedes cambiar tu propio rol.');
      }
      if (latest.primaryRole == role) {
        state = UsersState(users: _replace(latest));
        return;
      }
      final receipt = await _api.updateRoles(id, [role]);
      if (!_sameActor(actor)) {
        if (mounted) {
          state = const UsersState(
            error: 'La sesión cambió después del cambio confirmado.',
          );
        }
        return;
      }
      final verified =
          receipt.user != null &&
          receipt.user!.roles.length == 1 &&
          receipt.user!.roles.single == role;
      state = UsersState(
        users: receipt.user == null ? state.users : _replace(receipt.user!),
        updatedUserId: id,
        warning: verified ? null : 'El cambio fue confirmado, pero no se pudo verificar el rol solicitado. Actualiza el listado; no repitas el cambio.',
        unverifiedIds: {...state.unverifiedIds, if (!verified) id},
      );
      try {
        onChanged?.call();
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        state = UsersState(
          users: _sameActor(actor) ? state.users : const [],
          error: describeUserManagementError(e),
          unverifiedIds: state.unverifiedIds,
        );
      }
      rethrow;
    } finally {
      if (mounted && state.saving) {
        state = UsersState(
          users: state.users,
          error: state.error,
          warning: state.warning,
          unverifiedIds: state.unverifiedIds,
        );
      }
    }
  }

  List<User> _replace(User user) => List.unmodifiable([
    for (final existing in state.users)
      if (existing.id == user.id) user else existing,
  ]);
}

final userManagementActorProvider = Provider<User?>(
  (ref) => ref.watch(authNotifierProvider.select((s) => s.user)),
);
final usersNotifierProvider = StateNotifierProvider<UsersNotifier, UsersState>((
  ref,
) {
  final actor = ref.watch(userManagementActorProvider);
  final notifier = UsersNotifier(
    ref.watch(usersApiProvider),
    () => actor,
    onChanged: () {
      ref.invalidate(patientDoctorsProvider);
      ref.invalidate(sbarUsersProvider);
      ref.invalidate(dashboardNotifierProvider);
    },
  );
  Future.microtask(() {
    if (notifier.mounted) notifier.load();
  });
  return notifier;
});
