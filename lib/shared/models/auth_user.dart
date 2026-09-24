/// `AuthUser` schema (`GET /me`, `POST /auth/login`).
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.tenantId,
    required this.permissions,
    required this.roles,
    this.organizationId,
    this.departmentId,
    this.departmentName,
    this.avatarUpdatedAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String tenantId;
  final String? organizationId;
  final String? departmentId;
  final String? departmentName;
  final Set<String> permissions;
  final List<AuthRoleGrant> roles;
  final DateTime? avatarUpdatedAt;

  bool hasPermission(String permission) => permissions.contains(permission);

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: (json['display_name'] as String?) ?? '',
      tenantId: (json['tenant_id'] as String?) ?? '',
      organizationId: json['organization_id'] as String?,
      departmentId: json['department_id'] as String?,
      departmentName: json['department_name'] as String?,
      permissions: ((json['permissions'] as List?) ?? const [])
          .cast<String>()
          .toSet(),
      roles: ((json['roles'] as List?) ?? const [])
          .map((e) => AuthRoleGrant.fromJson(e as Map<String, dynamic>))
          .toList(),
      avatarUpdatedAt: json['avatar_updated_at'] is String
          ? DateTime.tryParse(json['avatar_updated_at'] as String)
          : null,
    );
  }

  /// Safe subset for the local profile cache (no secrets).
  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'display_name': displayName,
    'tenant_id': tenantId,
    if (organizationId != null) 'organization_id': organizationId,
    if (departmentId != null) 'department_id': departmentId,
    if (departmentName != null) 'department_name': departmentName,
    'permissions': permissions.toList(),
    'roles': roles.map((r) => r.toJson()).toList(),
    if (avatarUpdatedAt != null)
      'avatar_updated_at': avatarUpdatedAt!.toUtc().toIso8601String(),
  };

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return email.isNotEmpty ? email[0].toUpperCase() : '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

class AuthRoleGrant {
  const AuthRoleGrant({
    required this.role,
    required this.scopeType,
    this.scopeId,
  });
  final String role;
  final String scopeType;
  final String? scopeId;

  factory AuthRoleGrant.fromJson(Map<String, dynamic> json) => AuthRoleGrant(
    role: json['role'] as String,
    scopeType: (json['scope_type'] as String?) ?? '',
    scopeId: json['scope_id'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'role': role,
    'scope_type': scopeType,
    if (scopeId != null) 'scope_id': scopeId,
  };
}
