import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gondolier/core/network/api_error.dart';
import 'package:gondolier/core/network/auth_interceptor.dart';
import 'package:gondolier/core/network/auth_token_provider.dart';
import 'package:gondolier/data/models/create_activity_request_dto.dart';
import 'package:gondolier/data/repositories/dio_activity_api_repository.dart';

import '../../support/fake_http_client_adapter.dart';

class _FakeAuthTokenProvider implements AuthTokenProvider {
  _FakeAuthTokenProvider(this.token);

  final String? token;

  @override
  String? readAccessToken() => token;

  @override
  Future<void> dispose() async {}
}

Map<String, dynamic> _activityJson({required String id, int likes = 0}) {
  return {
    'id': id,
    'user_id': '11111111-1111-1111-1111-111111111111',
    'title': 'Session',
    'notes': null,
    'start_time': '2026-01-01T10:00:00Z',
    'duration_seconds': 1200,
    'distance_m': 5000,
    'avg_split_500m_seconds': 120,
    'avg_stroke_spm': 25,
    'visibility': 'public',
    'team_id': null,
    'route_geojson': null,
    'likes': likes,
    'comments': 0,
    'created_at': '2026-01-01T10:05:00Z',
  };
}

DioActivityApiRepository _buildRepository({
  required FakeHttpClientAdapter adapter,
  String? token,
  Future<Object?> Function()? loadDefaultRouteGeoJson,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(AuthInterceptor(_FakeAuthTokenProvider(token)));
  return DioActivityApiRepository(
    dio,
    loadDefaultRouteGeoJson:
        loadDefaultRouteGeoJson ??
        () async => <String, dynamic>{'type': 'FeatureCollection'},
  );
}

void main() {
  group('DioActivityApiRepository', () {
    test('supports list/create/get/like with mocked HTTP adapter', () async {
      final adapter = FakeHttpClientAdapter({
        'GET /api/v1/activities': StubResponse(
          statusCode: 200,
          data: [_activityJson(id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')],
        ),
        'POST /api/v1/activities': StubResponse(
          statusCode: 201,
          data: _activityJson(id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
        ),
        'GET /api/v1/activities/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb':
            StubResponse(
              statusCode: 200,
              data: _activityJson(id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
            ),
        'PATCH /api/v1/activities/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb/like':
            StubResponse(
              statusCode: 200,
              data: _activityJson(
                id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
                likes: 1,
              ),
            ),
      });

      final repository = _buildRepository(
        adapter: adapter,
        token: 'valid-token',
      );

      final list = await repository.listActivities();
      final created = await repository.createActivity(
        CreateActivityRequestDto(
          title: 'Test activity',
          startTime: DateTime.parse('2026-01-01T10:00:00Z'),
          visibility: 'public',
        ),
      );
      final fetched = await repository.getActivityById(created.id);
      final liked = await repository.likeActivity(created.id);

      expect(list, hasLength(1));
      expect(created.id, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
      expect(fetched.id, created.id);
      expect(liked.likes, 1);
      expect(adapter.requests, hasLength(4));
      expect(
        adapter.requests.first.headers['Authorization'],
        'Bearer valid-token',
      );
      expect(adapter.requests.first.queryParameters['scope'], 'following');

      final createRequest = adapter.requests[1];
      expect(createRequest.method, 'POST');
      expect(createRequest.path, '/api/v1/activities');
      final requestBody = Map<String, dynamic>.from(createRequest.data as Map);
      expect(requestBody['title'], 'Test activity');
      expect(requestBody['visibility'], 'public');
      expect(requestBody.containsKey('start_time'), isTrue);
      expect(requestBody.containsKey('route_geojson'), isTrue);
      expect(
        Map<String, dynamic>.from(requestBody['route_geojson'] as Map)['type'],
        'FeatureCollection',
      );
    });

    test('maps 401 response to ApiError.unauthorized', () async {
      final adapter = FakeHttpClientAdapter({
        'GET /api/v1/activities': const StubResponse(
          statusCode: 401,
          data: {'error': 'invalid token'},
        ),
      });

      final repository = _buildRepository(adapter: adapter, token: null);

      await expectLater(
        repository.listActivities(),
        throwsA(
          isA<ApiError>()
              .having((error) => error.type, 'type', ApiErrorType.unauthorized)
              .having((error) => error.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('maps 400 response to ApiError.badRequest', () async {
      final adapter = FakeHttpClientAdapter({
        'GET /api/v1/activities/not-a-uuid': const StubResponse(
          statusCode: 400,
          data: {'error': 'id must be a UUID'},
        ),
      });

      final repository = _buildRepository(
        adapter: adapter,
        token: 'valid-token',
      );

      await expectLater(
        repository.getActivityById('not-a-uuid'),
        throwsA(
          isA<ApiError>()
              .having((error) => error.type, 'type', ApiErrorType.badRequest)
              .having((error) => error.statusCode, 'statusCode', 400),
        ),
      );
    });

    test('keeps explicit route_geojson when request provides one', () async {
      final adapter = FakeHttpClientAdapter({
        'POST /api/v1/activities': StubResponse(
          statusCode: 201,
          data: _activityJson(id: 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
        ),
      });

      final repository = _buildRepository(
        adapter: adapter,
        token: 'valid-token',
        loadDefaultRouteGeoJson: () async => <String, dynamic>{
          'type': 'FeatureCollection',
        },
      );

      const explicitRoute = <String, dynamic>{
        'type': 'FeatureCollection',
        'features': <Object>[],
        'source': 'explicit',
      };

      await repository.createActivity(
        CreateActivityRequestDto(
          title: 'Custom route',
          startTime: DateTime.parse('2026-01-01T10:00:00Z'),
          visibility: 'public',
          routeGeoJson: explicitRoute,
        ),
      );

      final requestBody = Map<String, dynamic>.from(
        adapter.requests.single.data as Map,
      );
      expect(
        Map<String, dynamic>.from(
          requestBody['route_geojson'] as Map,
        )['source'],
        'explicit',
      );
    });

    test(
      'supports follow suggestions, follow/unfollow and metrics summary',
      () async {
        final adapter = FakeHttpClientAdapter({
          'GET /api/v1/follows/suggestions': const StubResponse(
            statusCode: 200,
            data: {
              'items': [
                {
                  'id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
                  'username': 'sarah',
                  'display_name': 'Sarah',
                  'avatar_url': null,
                  'last_public_activity': '2026-01-01T10:00:00Z',
                },
              ],
            },
          ),
          'PUT /api/v1/follows/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa':
              const StubResponse(statusCode: 204),
          'DELETE /api/v1/follows/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa':
              const StubResponse(statusCode: 204),
          'GET /api/v1/metrics/summary': const StubResponse(
            statusCode: 200,
            data: {
              'from': '2026-01-01T00:00:00Z',
              'to': '2026-01-07T23:59:59Z',
              'total_workouts': 4,
              'total_distance_m': 12000,
              'total_duration_seconds': 3600,
              'avg_split_500m_seconds': 120,
              'avg_stroke_spm': 24.5,
            },
          ),
        });

        final repository = _buildRepository(
          adapter: adapter,
          token: 'valid-token',
        );

        final suggestions = await repository.listFollowSuggestions(limit: 10);
        await repository.followUser('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
        await repository.unfollowUser('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
        final metrics = await repository.getMetricsSummary(
          from: DateTime.parse('2026-01-01T00:00:00Z'),
          to: DateTime.parse('2026-01-07T23:59:59Z'),
        );

        expect(suggestions, hasLength(1));
        expect(suggestions.first.username, 'sarah');
        expect(metrics.totalWorkouts, 4);
        expect(adapter.requests, hasLength(4));
        expect(adapter.requests[0].queryParameters['limit'], 10);
        expect(adapter.requests[3].queryParameters['from'], isNotEmpty);
        expect(adapter.requests[3].queryParameters['to'], isNotEmpty);
      },
    );
  });
}
