import 'package:dio/dio.dart';

import 'auth_token_provider.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._authTokenProvider);

  final AuthTokenProvider _authTokenProvider;

  static const Set<String> _publicPaths = {'/health', '/api/v1/health'};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final normalizedPath = _normalizePath(options.path);
    // Health checks stay public so local smoke tests work without auth.
    if (_publicPaths.contains(normalizedPath)) {
      handler.next(options);
      return;
    }

    // Read the freshest access token available from the auth provider.
    final token = _authTokenProvider.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  static String _normalizePath(String rawPath) {
    String path = rawPath;
    final uri = Uri.tryParse(rawPath);
    if (uri != null && uri.path.isNotEmpty) {
      path = uri.path;
    }

    if (!path.startsWith('/')) {
      path = '/$path';
    }

    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    return path;
  }
}
