import '../domain/models/feed_scope.dart';
import '../domain/models/follow_suggestion.dart';
import '../domain/models/post.dart';
import '../domain/models/weekly_summary.dart';
import 'feed_repository.dart';

class LocalFeedRepository implements FeedRepository {
  const LocalFeedRepository();

  @override
  Future<List<Post>> getPosts({FeedScope scope = FeedScope.following}) async {
    return const [
      Post(
        id: '00000000-0000-0000-0000-000000000001',
        userId: 'fallback-hugo',
        userName: 'Hugo',
        avatarUrl: null,
        timestamp: '22 Jan 2026 - Cork',
        title: 'Hard session on the ergometer today!',
        distance: '33.2 km',
        duration: '1h 12m',
        avgSplit: '2:10',
        strokeRate: '24 s/m',
        likes: 12,
      ),
      Post(
        id: '00000000-0000-0000-0000-000000000002',
        userId: 'fallback-sarah',
        userName: 'Sarah',
        avatarUrl: null,
        timestamp: '22 Jan 2026 - Cork',
        title: 'Morning 5k piece, feeling strong.',
        distance: '5.0 km',
        duration: '18m 30s',
        avgSplit: '1:51',
        strokeRate: '28 s/m',
        likes: 8,
      ),
    ];
  }

  @override
  Future<WeeklySummary> getWeeklySummary({
    required DateTime from,
    required DateTime to,
  }) async {
    return WeeklySummary(
      from: from,
      to: to,
      totalActivities: 2,
      totalDistanceKm: 38.2,
    );
  }

  @override
  Future<List<FollowSuggestion>> getFollowSuggestions({int limit = 5}) async {
    return const [
      FollowSuggestion(
        id: '11111111-1111-1111-1111-111111111111',
        userName: 'maria',
        displayName: 'Maria',
      ),
      FollowSuggestion(
        id: '22222222-2222-2222-2222-222222222222',
        userName: 'mark',
        displayName: 'Mark',
      ),
    ].take(limit).toList(growable: false);
  }

  @override
  Future<void> followUser(String userId) async {}

  @override
  Future<Post> likePost(String postId) async {
    final posts = await getPosts();
    final post = posts.firstWhere(
      (candidate) => candidate.id == postId,
      orElse: () => posts.first,
    );
    return post.copyWith(likes: post.likes + 1);
  }
}
