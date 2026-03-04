import '../models/activity_dto.dart';
import '../models/create_activity_request_dto.dart';
import '../models/follow_suggestion_dto.dart';
import '../models/metrics_summary_dto.dart';

abstract class ActivityApiRepository {
  Future<List<ActivityDto>> listActivities({String scope = 'following'});

  Future<ActivityDto> createActivity(CreateActivityRequestDto request);

  Future<ActivityDto> getActivityById(String id);

  Future<ActivityDto> likeActivity(String id);

  Future<void> followUser(String userId);

  Future<void> unfollowUser(String userId);

  Future<List<FollowSuggestionDto>> listFollowSuggestions({int limit = 5});

  Future<MetricsSummaryDto> getMetricsSummary({
    required DateTime from,
    required DateTime to,
  });
}
