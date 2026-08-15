import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

/// Singleton Dio-based HTTP client for the Rust backend (Pantheon API).
///
/// Adds `X-Shadow-Auth` automatically when a session token is available
/// and exposes helpers used by all service classes.
class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['X-Shadow-Auth'] = token;
          }
          handler.next(options);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._();

  static String _baseUrl = ShadowConstants.defaultApiUrl;
  late final Dio _dio;

  Dio get raw => _dio;

  static void overrideBaseUrl(String url) {
    _baseUrl = url;
    instance._dio.options.baseUrl = url;
  }

  Future<String?> _readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(ShadowConstants.authTokenKey);
  }

  Future<void> setAuthToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(ShadowConstants.authTokenKey);
    } else {
      await prefs.setString(ShadowConstants.authTokenKey, token);
    }
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _dio.get<T>(path, queryParameters: query);

  Future<Response<T>> post<T>(String path, {Object? data}) =>
      _dio.post<T>(path, data: data);

  Future<Response<T>> put<T>(String path, {Object? data}) =>
      _dio.put<T>(path, data: data);

  Future<Response<T>> delete<T>(String path, {Object? data}) =>
      _dio.delete<T>(path, data: data);
}
