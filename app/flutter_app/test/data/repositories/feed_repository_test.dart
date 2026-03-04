import 'package:flutter_test/flutter_test.dart';
import 'package:gondolier/core/network/api_error.dart';
import 'package:gondolier/data/models/activity_dto.dart';
import 'package:gondolier/data/models/create_activity_request_dto.dart';
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
  Future<List<ActivityDto>> listActivities() async {
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
  Future<ActivityDto> getActivityById(String id) {
    throw UnimplementedError();
  }

  @override
  Future<ActivityDto> likeActivity(String id) {
    throw UnimplementedError();
  }
}

void main() {
  group('FeedRepository', () {
    test(
      'returns fallback rows when remote activities list is empty',
      () async {
        final repository = FeedRepository(
          activityApiRepository: _FakeActivityApiRepository(
            listActivitiesResult: const <ActivityDto>[],
          ),
          useLocalFallback: false,
        );

        final activities = await repository.getFeedActivities();

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
        repository.getFeedActivities(),
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
