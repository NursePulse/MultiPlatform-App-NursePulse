import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sign_up_request.dart';
import '../../../core/network/dio_client.dart';
import '../domain/user.dart';
import '../domain/user_management_rules.dart';

class AuthenticatedSession {
  const AuthenticatedSession({required this.user, required this.token});

  final User user;
  final String token;
}

class AuthenticationApi {
  AuthenticationApi(this._dio);

  final Dio _dio;
  Future<AuthenticatedSession> signIn({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post(
      '/authentication/sign-in',
      data: {'username': username, 'password': password},
    );

    final json = response.data as Map<String, dynamic>;
    final user = User.fromJson(json);
    final token = json['token'];

    if (!user.hasKnownRole || token is! String || token.trim().isEmpty) {
      throw const FormatException(
        'La respuesta no contiene una sesión válida.',
      );
    }

    return AuthenticatedSession(user: user, token: token);
  }

  Future<User> signUp(SignUpRequest request) async {
    final response = await _dio.post(
      '/authentication/sign-up',
      data: request.toJson(),
    );
    return User.fromJson(response.data as Map<String, dynamic>);
  }
}

class RoleOption {
  const RoleOption({required this.id, required this.name});

  final int id;
  final String name;

  factory RoleOption.fromJson(Map<String, dynamic> json) =>
      RoleOption(id: json['id'] as int, name: json['name'] as String);
}

class RolesApi {
  RolesApi(this._dio);

  final Dio _dio;

  Future<List<RoleOption>> getAll() async {
    final response = await _dio.get('/roles');
    return (response.data as List)
        .map((e) => RoleOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class UserRolesWriteReceipt {
  const UserRolesWriteReceipt({required this.id, this.user, this.readError});
  final String id;
  final User? user;
  final Object? readError;
}

class UsersApi {
  UsersApi(this._dio);

  final Dio _dio;

  Future<List<User>> getAll() async {
    final response = await _dio.get('/users');
    return (response.data as List)
        .map((e) => User.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<User> getById(String id) async {
    final validated = UserManagementRules.id(id);
    final response = await _dio.get('/users/$validated');
    return _managedUser(response.data, validated);
  }

  User _managedUser(Object? data, String id) {
    if (data is! Map<String, dynamic> ||
        data['roles'] is! List ||
        (data['roles'] as List).isEmpty ||
        !(data['roles'] as List).every(UserManagementRules.roles.contains) ||
        data['username'] is! String ||
        (data['username'] as String).trim().isEmpty) {
      throw const FormatException(
        'La API no devolvió un usuario con roles válidos.',
      );
    }
    final user = User.fromJson(data);
    if (UserManagementRules.id(user.id) != id) {
      throw const FormatException(
        'La API devolvió otro usuario. Recarga el listado.',
      );
    }
    return User.fromJson({...data, 'id': id});
  }

  Future<UserRolesWriteReceipt> updateRoles(
    String userId,
    List<String> roles,
  ) async {
    final id = UserManagementRules.id(userId);
    final role = UserManagementRules.role(roles);
    final response = await _dio.patch(
      '/users/$id/roles',
      data: {
        'roles': [role],
      },
    );
    // Un PATCH 2xx ya fue confirmado: recuperar solo con GET, nunca repetir PATCH.
    try {
      return UserRolesWriteReceipt(
        id: id,
        user: _managedUser(response.data, id),
      );
    } catch (_) {
      try {
        return UserRolesWriteReceipt(id: id, user: await getById(id));
      } catch (e) {
        return UserRolesWriteReceipt(id: id, readError: e);
      }
    }
  }
}

final authenticationApiProvider = Provider(
  (ref) => AuthenticationApi(ref.watch(dioProvider)),
);
final usersApiProvider = Provider((ref) => UsersApi(ref.watch(dioProvider)));
final rolesApiProvider = Provider((ref) => RolesApi(ref.watch(dioProvider)));
