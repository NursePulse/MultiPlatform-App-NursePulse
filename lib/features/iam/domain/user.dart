const kRoleHeadAdminNurse = 'ROLE_HEAD_ADMIN_NURSE';
const kRoleNurse = 'ROLE_NURSE';
const _knownRoles = [kRoleHeadAdminNurse, kRoleNurse];

class User {
  const User({required this.id, required this.username, required this.roles});

  final String id;
  final String username;
  final List<String> roles;

  factory User.fromJson(Map<String, dynamic> json) {
    final rawRoles = (json['roles'] as List<dynamic>? ?? [])
        .map((r) => r.toString())
        .where(_knownRoles.contains)
        .toList();
    return User(
      id: json['id'].toString(),
      username: json['username'] as String,
      roles: rawRoles.isNotEmpty ? rawRoles : [kRoleNurse],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'roles': roles,
  };

  String get primaryRole {
    if (roles.contains(kRoleHeadAdminNurse)) return kRoleHeadAdminNurse;
    return kRoleNurse;
  }

  bool hasAnyRole(List<String> required) =>
      required.any((role) => roles.contains(role));
}

/// Demo-only display mode, independent of the user's real backend-enforced
/// permissions. Mirrors ViewModeStore from the Angular app.
enum ViewMode { headAdminNurse, nurse }

extension ViewModeX on ViewMode {
  String get storageValue => name;

  String get label => switch (this) {
    ViewMode.headAdminNurse => 'Jefe de Enfermería',
    ViewMode.nurse => 'Enfermera',
  };

  String get shortBadge => switch (this) {
    ViewMode.headAdminNurse => 'JE',
    ViewMode.nurse => 'EN',
  };

  ViewMode get next => switch (this) {
    ViewMode.headAdminNurse => ViewMode.nurse,
    ViewMode.nurse => ViewMode.headAdminNurse,
  };

  static ViewMode fromRole(String role) => switch (role) {
    kRoleHeadAdminNurse => ViewMode.headAdminNurse,
    _ => ViewMode.nurse,
  };

  static ViewMode fromStorage(String? value) => switch (value) {
    'headAdminNurse' => ViewMode.headAdminNurse,
    _ => ViewMode.nurse,
  };
}
