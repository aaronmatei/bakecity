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
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.register,
      data: {
        'phone': phone,
        'email': email,
        'password': password,
        if (displayName != null) 'display_name': displayName,
        'role': role,
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

  /// Fetches the currently authenticated user.
  Future<AuthUser> currentUser() async {
    final response = await _api.get<Map<String, dynamic>>(ApiEndpoints.me);
    final data = response.data;
    if (data == null) {
      throw const AuthException('No active session.');
    }
    final userJson = (data['user'] ?? data['data'] ?? data) as Map<String, dynamic>;
    return AuthUser.fromJson(userJson);
  }

  /// Clears local tokens; best-effort server-side logout.
  Future<void> logout() async {
    try {
      await _api.post<void>(ApiEndpoints.logout);
    } on AppException {
      // Ignore — local sign-out should still proceed.
    } finally {
      await _tokenStorage.clear();
    }
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
    return session.user;
  }
}
