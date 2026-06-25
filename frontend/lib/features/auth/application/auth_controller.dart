import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../services/auth_service.dart';
import '../domain/auth_user.dart';

/// High-level authentication status used for routing decisions.
enum AuthStatus { unknown, authenticated, unauthenticated }

/// Immutable auth state held by [AuthController].
class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isBusy = false,
    this.errorMessage,
  });

  final AuthStatus status;
  final AuthUser? user;
  final bool isBusy;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Owns the authentication session and exposes it to the router and UI.
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authServiceProvider))..bootstrap();
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._authService) : super(const AuthState());

  final AuthService _authService;

  /// Restores any persisted session on app start.
  Future<void> bootstrap() async {
    if (!await _authService.hasSession()) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await _authService.currentUser();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } on AppException {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearUser: true,
      );
    }
  }

  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    return _run(() => _authService.login(
          identifier: identifier,
          password: password,
        ));
  }

  Future<bool> register({
    required String phone,
    required String email,
    required String password,
    String? displayName,
    String role = 'customer',
  }) async {
    return _run(() => _authService.register(
          phone: phone,
          email: email,
          password: password,
          displayName: displayName,
          role: role,
        ));
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<bool> _run(Future<AuthUser> Function() action) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final user = await action();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        isBusy: false,
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isBusy: false, errorMessage: e.message);
      return false;
    }
  }
}
