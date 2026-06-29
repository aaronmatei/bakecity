import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../core/constants/api_endpoints.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/storage/token_storage.dart';

/// Provides the singleton [Logger] used across the app.
final loggerProvider = Provider<Logger>((ref) {
  return Logger(printer: PrettyPrinter(methodCount: 0));
});

/// Provides the [TokenStorage]. Must be overridden in `main` with the
/// initialised instance (it requires async setup).
final tokenStorageProvider = Provider<TokenStorage>((ref) {
  throw UnimplementedError(
    'tokenStorageProvider must be overridden in ProviderScope.',
  );
});

/// Provides a configured [ApiClient].
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokenStorage: ref.watch(tokenStorageProvider),
    logger: ref.watch(loggerProvider),
  );
});

/// Thin wrapper around [Dio] that applies base options, auth + logging
/// interceptors and maps failures to typed [AppException]s.
class ApiClient {
  ApiClient({
    required TokenStorage tokenStorage,
    required Logger logger,
    Dio? dio,
  })  : _tokenStorage = tokenStorage,
        _logger = logger,
        _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: AppConstants.networkTimeoutSeconds),
      receiveTimeout: const Duration(seconds: AppConstants.networkTimeoutSeconds),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    );
    _dio.interceptors.add(_authInterceptor());
    _dio.interceptors.add(_loggingInterceptor());
  }

  final Dio _dio;
  final TokenStorage _tokenStorage;
  final Logger _logger;

  /// Underlying Dio instance, exposed for advanced use (e.g. uploads).
  Dio get dio => _dio;

  InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokenStorage.readAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    );
  }

  InterceptorsWrapper _loggingInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        _logger.d('--> ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        _logger.d(
          '<-- ${response.statusCode} ${response.requestOptions.uri}',
        );
        handler.next(response);
      },
      onError: (error, handler) {
        _logger.w(
          'xx- ${error.response?.statusCode} ${error.requestOptions.uri}: '
          '${error.message}',
        );
        handler.next(error);
      },
    );
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _guard(() => _dio.get<T>(path, queryParameters: queryParameters));
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) {
    return _guard(
      () => _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: headers == null ? null : Options(headers: headers),
      ),
    );
  }

  Future<Response<T>> put<T>(String path, {Object? data}) {
    return _guard(() => _dio.put<T>(path, data: data));
  }

  Future<Response<T>> patch<T>(String path, {Object? data}) {
    return _guard(() => _dio.patch<T>(path, data: data));
  }

  Future<Response<T>> delete<T>(String path, {Object? data}) {
    return _guard(() => _dio.delete<T>(path, data: data));
  }

  Future<Response<T>> _guard<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } catch (error) {
      throw mapDioError(error);
    }
  }
}
