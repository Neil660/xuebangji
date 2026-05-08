import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _baseUrl = 'http://localhost:3000/api/v1'; // 生产时替换

class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        contentType: 'application/json',
      ),
    );

    _dio.interceptors.addAll([
      _AuthInterceptor(_storage, _dio),
      LogInterceptor(requestBody: true, responseBody: true, logPrint: _log),
    ]);
  }

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  Dio get dio => _dio;

  void _log(Object obj) {
    // ignore: avoid_print
    assert(() { print('[API] $obj'); return true; }());
  }

  // ── CRUD 便捷方法 ─────────────────────────────────────────

  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async {
    final resp = await _dio.get(path, queryParameters: params);
    return resp.data;
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    final resp = await _dio.post(path, data: data);
    return resp.data;
  }

  Future<dynamic> put(String path, {dynamic data}) async {
    final resp = await _dio.put(path, data: data);
    return resp.data;
  }

  Future<dynamic> patch(String path, {dynamic data}) async {
    final resp = await _dio.patch(path, data: data);
    return resp.data;
  }

  Future<dynamic> delete(String path) async {
    final resp = await _dio.delete(path);
    return resp.data;
  }

  Future<dynamic> upload(String path, FormData formData) async {
    final resp = await _dio.post(path, data: formData);
    return resp.data;
  }
}

// ── Auth 拦截器：自动注入 token + 无感刷新 ────────────────────

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage, this._dio);

  final FlutterSecureStorage _storage;
  final Dio _dio;
  bool _refreshing = false;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 &&
        err.response?.data?['code'] == 4011 &&
        !_refreshing) {
      _refreshing = true;
      try {
        final refreshToken = await _storage.read(key: 'refresh_token');
        if (refreshToken == null) {
          _clearTokensAndRedirect();
          return handler.next(err);
        }

        final resp = await _dio.post('/auth/refresh', data: {'refreshToken': refreshToken});
        final newAccess = resp.data['data']['accessToken'] as String;
        final newRefresh = resp.data['data']['refreshToken'] as String;

        await _storage.write(key: 'access_token', value: newAccess);
        await _storage.write(key: 'refresh_token', value: newRefresh);

        // 重试原请求
        err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
        final retry = await _dio.fetch(err.requestOptions);
        return handler.resolve(retry);
      } catch (_) {
        _clearTokensAndRedirect();
        return handler.next(err);
      } finally {
        _refreshing = false;
      }
    }
    handler.next(err);
  }

  void _clearTokensAndRedirect() {
    _storage.delete(key: 'access_token');
    _storage.delete(key: 'refresh_token');
    // 通过全局 navigatorKey 跳转登录页
  }
}

// ── Provider ─────────────────────────────────────────────────

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.instance);
