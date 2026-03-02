import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gondolier/core/network/auth_interceptor.dart';
import 'package:gondolier/core/network/auth_token_provider.dart';

import '../../support/fake_http_client_adapter.dart';

class _FakeAuthTokenProvider implements AuthTokenProvider {
  _FakeAuthTokenProvider(this.token);

  final String? token;

  @override
  String? readAccessToken() => token;

  @override
  Future<void> dispose() async {}
}

void main() {
  group('AuthInterceptor', () {
    test('adds bearer token for protected routes', () async {
      final adapter = FakeHttpClientAdapter({
        'GET /api/v1/activities': const StubResponse(statusCode: 200, data: []),
      });

      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(
        AuthInterceptor(_FakeAuthTokenProvider('token-123')),
      );

      await dio.get('/api/v1/activities');

      expect(adapter.requests, hasLength(1));
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer token-123',
      );
    });

    test('does not add bearer token to public health routes', () async {
      final adapter = FakeHttpClientAdapter({
        'GET /api/v1/health': const StubResponse(
          statusCode: 200,
          data: {'status': 'ok', 'time': '2026-03-02T10:00:00Z'},
        ),
      });

      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(
        AuthInterceptor(_FakeAuthTokenProvider('token-xyz')),
      );

      final response = await dio.get('/api/v1/health');
      final payload = Map<String, dynamic>.from(response.data as Map);

      expect(payload['status'], 'ok');
      expect(payload['time'], '2026-03-02T10:00:00Z');
      expect(adapter.requests, hasLength(1));
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('does not add bearer token to root health route', () async {
      final adapter = FakeHttpClientAdapter({
        'GET /health': const StubResponse(
          statusCode: 200,
          data: {'status': 'ok'},
        ),
      });

      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(
        AuthInterceptor(_FakeAuthTokenProvider('token-xyz')),
      );

      await dio.get('/health');

      expect(adapter.requests, hasLength(1));
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });
  });
}
