import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/secure_store.dart';
import 'session_events.dart';

/// Adds the JWT bearer token to every request except authentication calls,
/// and reports 401s (outside of authentication calls) so the app can force
/// a sign-out. Mirrors auth.interceptor.ts.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._secureStore, this._ref);

  final SecureStore _secureStore;
  final Ref _ref;

  bool _isAuthCall(String path) => path.contains('/authentication/');

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isAuthCall(options.path)) {
      final token = await _secureStore.readToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final path = err.requestOptions.path;
    if (err.response?.statusCode == 401 && !_isAuthCall(path)) {
      _ref.read(unauthorizedEventProvider.notifier).trigger();
    }
    handler.next(err);
  }
}

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json', 'Accept-Language': 'es'},
    ),
  );
  dio.interceptors.add(_AuthInterceptor(ref.read(secureStoreProvider), ref));
  return dio;
});
