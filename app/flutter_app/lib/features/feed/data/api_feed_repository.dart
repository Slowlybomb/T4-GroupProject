import '../../../data/models/activity_model.dart';
import '../../../data/repositories/feed_repository.dart' as data_feed;
import '../domain/models/post.dart';
import 'feed_repository.dart';

class ApiFeedRepository implements FeedRepository {
  final data_feed.FeedRepository _activityFeedRepository;

  const ApiFeedRepository({
    required data_feed.FeedRepository activityFeedRepository,
  }) : _activityFeedRepository = activityFeedRepository;

  @override
  Future<List<Post>> getPosts() async {
    final activities = await _activityFeedRepository.getFeedActivities();
    return activities.map(_toPost).toList(growable: false);
  }

  static Post _toPost(ActivityModel activity) {
    return Post(
      userName: activity.userName,
      avatarUrl: activity.avatarUrl,
      timestamp: activity.timestamp,
      title: activity.title,
      distance: activity.distance,
      duration: activity.duration,
      avgSplit: activity.avgSplit,
      strokeRate: activity.strokeRate,
      likes: activity.likes,
    );
  }
}
