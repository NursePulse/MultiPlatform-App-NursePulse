const kRoleAdmin = 'ROLE_ADMIN';
const kRoleDoctor = 'ROLE_DOCTOR';
const kRoleNurse = 'ROLE_NURSE';
const _knownRoles = [kRoleAdmin, kRoleDoctor, kRoleNurse];

class User {
  const User({
    required this.id,
    required this.username,
    required this.roles,
    this.firstName = '',
    this.lastName = '',
  });

  final String id;
  final String username;
  final List<String> roles;
  final String firstName;
  final String lastName;

  String get displayName =>
      firstName.trim().isNotEmpty && lastName.trim().isNotEmpty
      ? '${firstName.trim()} ${lastName.trim()}'
      : username;

  factory User.fromJson(Map<String, dynamic> json) {
    final rawRoles = (json['roles'] as List<dynamic>? ?? [])
        .map((r) => r.toString())
        .where(_knownRoles.contains)
        .toList();

    return User(
      id: json['id'].toString(),
      username: json['username'] as String,
      roles: List.unmodifiable(rawRoles),
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'roles': roles,
    'firstName': firstName,
    'lastName': lastName,
  };

  String get primaryRole {
    for (final role in _knownRoles) {
      if (roles.contains(role)) return role;
    }
    return '';
  }

  bool get hasKnownRole => roles.any(_knownRoles.contains);

  bool hasAnyRole(List<String> required) =>
      required.any((role) => roles.contains(role));
}

enum ViewMode { admin, doctor, nurse, unknown }

extension ViewModeX on ViewMode {
  String get storageValue => name;

  String get label => switch (this) {
    ViewMode.admin => 'Administrador',
    ViewMode.doctor => 'Medicina',
    ViewMode.nurse => 'Enfermera',
    ViewMode.unknown => 'Sin rol válido',
  };

  String get shortBadge => switch (this) {
    ViewMode.admin => 'AD',
    ViewMode.doctor => 'ME',
    ViewMode.nurse => 'EN',
    ViewMode.unknown => '?',
  };

  ViewMode get next => switch (this) {
    ViewMode.admin => ViewMode.doctor,
    ViewMode.doctor => ViewMode.nurse,
    ViewMode.nurse => ViewMode.admin,
    ViewMode.unknown => ViewMode.unknown,
  };

  static ViewMode fromRole(String role) => switch (role) {
    kRoleAdmin => ViewMode.admin,
    kRoleDoctor => ViewMode.doctor,
    kRoleNurse => ViewMode.nurse,
    _ => ViewMode.unknown,
  };

  static ViewMode fromStorage(String? value) => switch (value) {
    'admin' => ViewMode.admin,
    'doctor' => ViewMode.doctor,
    'nurse' => ViewMode.nurse,
    _ => ViewMode.unknown,
  };
}
