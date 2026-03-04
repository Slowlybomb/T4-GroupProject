import '../domain/models/feed_scope.dart';
import '../domain/models/follow_suggestion.dart';
import '../domain/models/post.dart';
import '../domain/models/weekly_summary.dart';

abstract class FeedRepository {
  Future<List<Post>> getPosts({FeedScope scope = FeedScope.following});

  Future<WeeklySummary> getWeeklySummary({
    required DateTime from,
    required DateTime to,
  });

  Future<List<FollowSuggestion>> getFollowSuggestions({int limit = 5});

  Future<void> followUser(String userId);

  Future<Post> likePost(String postId);
}
