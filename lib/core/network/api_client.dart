import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import 'api_exceptions.dart';

/// Single point of contact with the ReceiptSystem.API backend.
///
/// Centralizes three things every call needs, so call sites never touch
/// Dio directly: attaching the current Supabase session's JWT as a Bearer
/// token, mapping failures into [NetworkException] (no response reached
/// the server) vs [ApiErrorException] (server responded with an error),
/// and (debug builds only) logging every request/response/error so
/// connectivity issues are visible instead of silent.
class ApiClient {
  ApiClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: Env.apiBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              // ngrok's free tier serves an HTML "you're about to visit..."
              // interstitial in place of the real response unless this
              // header is present - without it, every call would get HTML
              // back instead of JSON, which looks like a hung/failed
              // request. Harmless against a non-ngrok backend.
              headers: const {'ngrok-skip-browser-warning': 'true'},
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;
          if (accessToken != null) {
            options.headers['Authorization'] = 'Bearer $accessToken';
            _log('Attached Bearer token (${_redact(accessToken)})');
          } else {
            _log('No Supabase session - request going out WITHOUT a Bearer token');
          }
          handler.next(options);
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestHeader: true,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
          logPrint: (obj) => debugPrint('[API] $obj'),
        ),
      );
    }
  }

  final Dio _dio;

  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _wrap(() => _dio.get(path, queryParameters: queryParameters));
  }

  Future<Response<dynamic>> post(String path, {Object? data}) {
    return _wrap(() => _dio.post(path, data: data));
  }

  Future<Response<dynamic>> _wrap(Future<Response<dynamic>> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      final mapped = _mapError(e);
      _log('Request failed: ${e.requestOptions.method} ${e.requestOptions.uri} -> $mapped');
      throw mapped;
    }
  }

  ApiException _mapError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const NetworkException();

      case DioExceptionType.badCertificate:
        return const NetworkException('Could not verify the server certificate.');

      case DioExceptionType.cancel:
        return const NetworkException('Request was cancelled.');

      case DioExceptionType.badResponse:
        final response = e.response!;
        final data = response.data;
        String message = 'Request failed (${response.statusCode}).';
        String? code;
        if (data is Map) {
          message = data['error'] as String? ?? message;
          code = data['code'] as String?;
        }
        return ApiErrorException(statusCode: response.statusCode ?? 0, message: message, code: code);

      case DioExceptionType.unknown:
        return const NetworkException();
    }
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[API] $message');
  }

  /// Never log a full session token - just enough to tell one session from
  /// another in the log output.
  String _redact(String token) => token.length <= 12 ? '***' : '${token.substring(0, 8)}...';
}
