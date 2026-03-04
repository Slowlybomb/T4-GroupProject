import 'package:flutter_test/flutter_test.dart';
import 'package:gondolier/core/network/api_error.dart';
import 'package:gondolier/data/models/activity_dto.dart';
import 'package:gondolier/data/models/create_activity_request_dto.dart';
import 'package:gondolier/data/models/follow_suggestion_dto.dart';
import 'package:gondolier/data/models/metrics_summary_dto.dart';
import 'package:gondolier/data/repositories/activity_api_repository.dart';
import 'package:gondolier/data/repositories/feed_repository.dart';

class _FakeActivityApiRepository implements ActivityApiRepository {
  _FakeActivityApiRepository({
    this.listActivitiesResult = const <ActivityDto>[],
    this.listActivitiesError,
  });

  final List<ActivityDto> listActivitiesResult;
  final Object? listActivitiesError;

  @override
  Future<List<ActivityDto>> listActivities({String scope = 'following'}) async {
    final error = listActivitiesError;
    if (error != null) {
      throw error;
    }
    return listActivitiesResult;
  }

  @override
  Future<ActivityDto> createActivity(CreateActivityRequestDto request) {
    throw UnimplementedError();
  }

  @override
  Future<void> followUser(String userId) async {}

  @override
  Future<ActivityDto> getActivityById(String id) {
    throw UnimplementedError();
  }

  @override
  Future<MetricsSummaryDto> getMetricsSummary({
    required DateTime from,
    required DateTime to,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ActivityDto> likeActivity(String id) {
    throw UnimplementedError();
  }

  @override
  Future<List<FollowSuggestionDto>> listFollowSuggestions({int limit = 5}) {
    throw UnimplementedError();
  }

  @override
  Future<void> unfollowUser(String userId) async {}
}

void main() {
  group('FeedRepository', () {
    test(
      'returns empty list when remote feed is empty and fallback is disabled',
      () async {
        final repository = FeedRepository(
          activityApiRepository: _FakeActivityApiRepository(
            listActivitiesResult: const <ActivityDto>[],
          ),
          useLocalFallback: false,
        );

        final activities = await repository.getFeedActivities(
          scope: 'following',
        );

        expect(activities, isEmpty);
      },
    );

    test(
      'returns fallback rows when remote feed is empty and fallback is enabled',
      () async {
        final repository = FeedRepository(
          activityApiRepository: _FakeActivityApiRepository(
            listActivitiesResult: const <ActivityDto>[],
          ),
          useLocalFallback: true,
        );

        final activities = await repository.getFeedActivities(
          scope: 'following',
        );

        expect(activities, isNotEmpty);
        expect(activities.first.userName, isNotEmpty);
      },
    );

    test('rethrows api error when fallback is disabled', () async {
      final repository = FeedRepository(
        activityApiRepository: _FakeActivityApiRepository(
          listActivitiesError: const ApiError(
            type: ApiErrorType.unauthorized,
            message: 'unauthorized',
            statusCode: 401,
          ),
        ),
        useLocalFallback: false,
      );

      await expectLater(
        repository.getFeedActivities(scope: 'following'),
        throwsA(
          isA<ApiError>().having(
            (error) => error.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });
  });
}
