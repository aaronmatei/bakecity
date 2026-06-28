import 'package:dio/dio.dart';

/// Base type for all application-level errors.
sealed class AppException implements Exception {
  const AppException(this.message);

  /// Human-readable description of the error.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Connectivity / transport-level failure (timeout, no connection, etc.).
class NetworkException extends AppException {
  const NetworkException([super.message = 'Network connection failed.']);
}

/// The server returned a non-success HTTP status.
class ApiException extends AppException {
  const ApiException({
    required this.statusCode,
    required String message,
    this.code,
  }) : super(message);

  /// HTTP status code.
  final int statusCode;

  /// Optional machine-readable error code from the API body.
  final String? code;

  @override
  String toString() => 'ApiException($statusCode${code != null ? ', $code' : ''}): $message';
}

/// Authentication / authorisation failure (401 / 403).
class AuthException extends AppException {
  const AuthException([super.message = 'Authentication required.']);
}

/// Client-side or server-side validation failure (422 / 400).
class ValidationException extends AppException {
  const ValidationException(
    super.message, {
    this.fieldErrors = const {},
  });

  /// Field-keyed validation messages, e.g. `{ 'email': 'is invalid' }`.
  final Map<String, String> fieldErrors;
}

/// Fallback for anything we cannot classify.
class UnknownException extends AppException {
  const UnknownException([super.message = 'Something went wrong.']);
}

/// Maps a [DioException] (or arbitrary error) to a typed [AppException].
AppException mapDioError(Object error) {
  if (error is AppException) return error;
  if (error is! DioException) {
    return UnknownException(error.toString());
  }

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const NetworkException('The request timed out.');
    case DioExceptionType.connectionError:
      return const NetworkException('Could not reach the server.');
    case DioExceptionType.cancel:
      return const NetworkException('The request was cancelled.');
    case DioExceptionType.badCertificate:
      return const NetworkException('Invalid server certificate.');
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      final response = error.response;
      final statusCode = response?.statusCode ?? 0;
      final body = response?.data;
      final message = _extractMessage(body) ?? error.message ?? 'Request failed.';
      final code = _extractCode(body);

      if (statusCode == 401 || statusCode == 403) {
        return AuthException(message);
      }
      if (statusCode == 400 || statusCode == 422) {
        return ValidationException(
          message,
          fieldErrors: _extractFieldErrors(body),
        );
      }
      if (statusCode == 0) {
        return NetworkException(message);
      }
      return ApiException(
        statusCode: statusCode,
        message: message,
        code: code,
      );
  }
}

String? _extractMessage(Object? body) {
  if (body is Map) {
    final value = body['message'] ?? body['error'] ?? body['detail'];
    if (value is String && value.isNotEmpty) return value;
  }
  return null;
}

String? _extractCode(Object? body) {
  if (body is Map) {
    final value = body['code'];
    if (value is String && value.isNotEmpty) return value;
  }
  return null;
}

Map<String, String> _extractFieldErrors(Object? body) {
  if (body is Map && body['errors'] is Map) {
    final errors = body['errors'] as Map;
    return errors.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }
  return const {};
}
