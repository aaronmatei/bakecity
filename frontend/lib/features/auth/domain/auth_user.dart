import '../../../core/constants/app_constants.dart';

/// The currently authenticated user.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.phone,
    required this.role,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.bakerVerified = false,
  });

  final String id;
  final String phone;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final UserRole role;

  /// Whether a baker's KYC/verification has been approved.
  final bool bakerVerified;

  bool get isBaker => role == UserRole.baker;
  bool get isCustomer => role == UserRole.customer;
  bool get isAdmin => role == UserRole.admin;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] ?? json['user_id']).toString(),
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      displayName: json['display_name'] as String? ?? json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: _roleFromJson(json),
      bakerVerified: json['baker_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'email': email,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'role': role.name,
        'baker_verified': bakerVerified,
      };

  /// Resolves the role from either a `role_mask` bitmask (the backend's wire
  /// format: 1=customer, 2=baker, 4=admin) or a legacy `role` string.
  static UserRole _roleFromJson(Map<String, dynamic> json) {
    final mask = json['role_mask'];
    if (mask is int) return roleFromMask(mask);
    return _parseRole(json['role'] as String?);
  }

  /// Maps the `users.role_mask` bitmask to a role (highest privilege wins).
  static UserRole roleFromMask(int mask) {
    if (mask & 4 != 0) return UserRole.admin;
    if (mask & 2 != 0) return UserRole.baker;
    return UserRole.customer;
  }

  static UserRole _parseRole(String? value) {
    switch (value) {
      case 'baker':
        return UserRole.baker;
      case 'admin':
        return UserRole.admin;
      case 'customer':
      default:
        return UserRole.customer;
    }
  }

  AuthUser copyWith({
    String? displayName,
    String? avatarUrl,
    bool? bakerVerified,
  }) {
    return AuthUser(
      id: id,
      phone: phone,
      email: email,
      role: role,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bakerVerified: bakerVerified ?? this.bakerVerified,
    );
  }
}

/// Server response to a successful login / register call.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.user,
    this.refreshToken,
  });

  final String accessToken;
  final String? refreshToken;
  final AuthUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    // The backend returns a flat AuthResponse: {user_id, token, role_mask,
    // expires_at} — no nested user and no refresh token. Build a minimal user
    // from it; the full profile is fetched separately from GET /me.
    final userJson = (json['user'] ?? json['data']) as Map<String, dynamic>?;
    return AuthSession(
      accessToken: (json['token'] ?? json['access_token']) as String? ?? '',
      refreshToken: json['refresh_token'] as String?,
      user: AuthUser.fromJson(userJson ?? json),
    );
  }
}
