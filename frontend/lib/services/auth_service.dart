import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../core/errors/app_exception.dart';
import '../core/storage/token_storage.dart';
import '../features/auth/domain/auth_user.dart';
import 'api_client.dart';

/// Provides the [AuthService].
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    api: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

/// Handles credential exchange and token lifecycle with the backend.
class AuthService {
  AuthService({
    required ApiClient api,
    required TokenStorage tokenStorage,
  })  : _api = api,
        _tokenStorage = tokenStorage;

  final ApiClient _api;
  final TokenStorage _tokenStorage;

  /// Registers a new account and persists the returned session token.
  Future<AuthUser> register({
    required String phone,
    required String email,
    required String password,
    String? displayName,
    String role = 'customer',
    String? businessName,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.register,
      data: {
        'phone': phone,
        'email': email,
        'password': password,
        if (displayName != null) 'display_name': displayName,
        'role': role,
        if (businessName != null && businessName.trim().isNotEmpty)
          'business_name': businessName.trim(),
      },
    );
    return _persistSession(response.data);
  }

  /// Logs in with phone (or email) + password and persists the token.
  Future<AuthUser> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      data: {
        'identifier': identifier,
        'password': password,
      },
    );
    return _persistSession(response.data);
  }

  /// Fetches the currently authenticated user. For bakers, also resolves
  /// verification state from their profile so routing can skip onboarding once
  /// approved.
  Future<AuthUser> currentUser() async {
    final response = await _api.get<Map<String, dynamic>>(ApiEndpoints.me);
    final data = response.data;
    if (data == null) {
      throw const AuthException('No active session.');
    }
    final userJson = (data['user'] ?? data['data'] ?? data) as Map<String, dynamic>;
    final user = AuthUser.fromJson(userJson);
    if (user.isBaker) {
      return user.copyWith(bakerVerified: await _bakerApproved());
    }
    return user;
  }

  /// Whether the signed-in baker's profile has been approved (gates publishing
  /// and routes them past onboarding). Best-effort: any failure — including no
  /// profile yet — is treated as not-yet-verified.
  Future<bool> _bakerApproved() async {
    try {
      final response =
          await _api.get<Map<String, dynamic>>(ApiEndpoints.myBaker);
      return response.data?['status'] == 'approved';
    } on AppException {
      return false;
    }
  }

  /// Clears local tokens; best-effort server-side logout.
  /// Clears local tokens. The backend issues stateless JWTs and has no logout
  /// endpoint, so sign-out is purely local (the token simply expires).
  Future<void> logout() async {
    await _tokenStorage.clear();
  }

  Future<bool> hasSession() => _tokenStorage.hasToken;

  Future<AuthUser> _persistSession(Map<String, dynamic>? data) async {
    if (data == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'Empty authentication response.',
      );
    }
    final session = AuthSession.fromJson(data);
    if (session.accessToken.isEmpty) {
      throw const AuthException('Missing access token in response.');
    }
    await _tokenStorage.writeTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
    // The register/login response only carries user_id + role_mask; fetch the
    // full profile now that the token is stored. Fall back to the minimal user.
    try {
      return await currentUser();
    } on AppException {
      return session.user;
    }
  }
}
