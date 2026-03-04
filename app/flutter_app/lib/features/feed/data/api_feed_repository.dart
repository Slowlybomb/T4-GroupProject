import '../../../data/models/activity_model.dart';
import '../../../data/models/follow_suggestion_dto.dart';
import '../../../data/models/metrics_summary_dto.dart';
import '../../../data/repositories/feed_repository.dart' as data_feed;
import '../domain/models/feed_scope.dart';
import '../domain/models/follow_suggestion.dart';
import '../domain/models/post.dart';
import '../domain/models/weekly_summary.dart';
import 'feed_repository.dart';

class ApiFeedRepository implements FeedRepository {
  const ApiFeedRepository({
    required data_feed.FeedRepository activityFeedRepository,
  }) : _activityFeedRepository = activityFeedRepository;

  final data_feed.FeedRepository _activityFeedRepository;

  @override
  Future<List<Post>> getPosts({FeedScope scope = FeedScope.following}) async {
    final activities = await _activityFeedRepository.getFeedActivities(
      scope: _scopeValue(scope),
    );
    return activities.map(_toPost).toList(growable: false);
  }

  @override
  Future<WeeklySummary> getWeeklySummary({
    required DateTime from,
    required DateTime to,
  }) async {
    final summary = await _activityFeedRepository.getMetricsSummary(
      from: from,
      to: to,
    );
    return _toWeeklySummary(summary);
  }

  @override
  Future<List<FollowSuggestion>> getFollowSuggestions({int limit = 5}) async {
    final suggestions = await _activityFeedRepository.getFollowSuggestions(
      limit: limit,
    );
    return suggestions.map(_toSuggestion).toList(growable: false);
  }

  @override
  Future<void> followUser(String userId) {
    return _activityFeedRepository.followUser(userId);
  }

  @override
  Future<Post> likePost(String postId) async {
    final activity = await _activityFeedRepository.likeActivity(postId);
    return _toPost(activity);
  }

  static String _scopeValue(FeedScope scope) {
    switch (scope) {
      case FeedScope.following:
        return 'following';
      case FeedScope.global:
        return 'global';
      case FeedScope.friends:
        return 'friends';
    }
  }

  static FollowSuggestion _toSuggestion(FollowSuggestionDto suggestion) {
    return FollowSuggestion(
      id: suggestion.id,
      userName: suggestion.username,
      displayName: suggestion.displayName,
      avatarUrl: suggestion.avatarUrl,
      lastPublicActivity: suggestion.lastPublicActivity,
    );
  }

  static WeeklySummary _toWeeklySummary(MetricsSummaryDto summary) {
    return WeeklySummary(
      from: summary.from,
      to: summary.to,
      totalActivities: summary.totalWorkouts,
      totalDistanceKm: summary.totalDistanceM / 1000,
    );
  }

  static Post _toPost(ActivityModel activity) {
    return Post(
      id: activity.id,
      userId: activity.userId,
      userName: activity.userName,
      avatarUrl: activity.avatarUrl,
      timestamp: activity.timestamp,
      title: activity.title,
      distance: activity.distance,
      duration: activity.duration,
      avgSplit: activity.avgSplit,
      strokeRate: activity.strokeRate,
      likes: activity.likes,
      comments: activity.comments,
      routePoints: activity.routeCoordinates
          .where((pair) => pair.length >= 2)
          .map((pair) => RoutePoint(longitude: pair[0], latitude: pair[1]))
          .toList(growable: false),
    );
  }
}
