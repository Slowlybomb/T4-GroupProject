import 'package:flutter_test/flutter_test.dart';
import 'package:gondolier/features/feed/controller/feed_controller.dart';
import 'package:gondolier/features/feed/data/feed_repository.dart';
import 'package:gondolier/features/feed/domain/models/feed_scope.dart';
import 'package:gondolier/features/feed/domain/models/follow_suggestion.dart';
import 'package:gondolier/features/feed/domain/models/post.dart';
import 'package:gondolier/features/feed/domain/models/weekly_summary.dart';

class _FakeFeedRepository implements FeedRepository {
  _FakeFeedRepository({
    this.posts = const <Post>[],
    this.suggestions = const <FollowSuggestion>[],
    this.postsError,
    this.likeResult,
  });

  final List<Post> posts;
  final List<FollowSuggestion> suggestions;
  final Object? postsError;
  final Post? likeResult;
  FeedScope lastScope = FeedScope.following;
  String? lastFollowedUserId;

  @override
  Future<void> followUser(String userId) async {
    lastFollowedUserId = userId;
  }

  @override
  Future<List<FollowSuggestion>> getFollowSuggestions({int limit = 5}) async {
    return suggestions.take(limit).toList(growable: false);
  }

  @override
  Future<List<Post>> getPosts({FeedScope scope = FeedScope.following}) async {
    lastScope = scope;
    if (postsError != null) {
      throw postsError!;
    }
    return posts;
  }

  @override
  Future<WeeklySummary> getWeeklySummary({
    required DateTime from,
    required DateTime to,
  }) async {
    return WeeklySummary(
      from: from,
      to: to,
      totalActivities: 1,
      totalDistanceKm: 5.0,
    );
  }

  @override
  Future<Post> likePost(String postId) async {
    return likeResult ??
        const Post(
          id: 'post-1',
          userId: 'user-1',
          userName: 'Hugo',
          timestamp: 'Now',
          title: 'Liked',
          distance: '1000 m',
          duration: '5m',
          avgSplit: '2:30',
          strokeRate: '24',
          likes: 2,
        );
  }
}

void main() {
  group('FeedController', () {
    test('loadPosts populates posts and summary', () async {
      final controller = FeedController(
        feedRepository: _FakeFeedRepository(
          posts: const [
            Post(
              id: 'post-1',
              userId: 'user-1',
              userName: 'Hugo',
              timestamp: 'Now',
              title: 'Test title',
              distance: '1000 m',
              duration: '5m',
              avgSplit: '2:30',
              strokeRate: '24',
            ),
          ],
        ),
      );

      await controller.loadPosts();

      expect(controller.posts, hasLength(1));
      expect(controller.errorMessage, isNull);
      expect(controller.weeklySummary, isNotNull);
      expect(controller.isLoading, isFalse);
    });

    test('loadPosts exposes user-friendly error on failure', () async {
      final controller = FeedController(
        feedRepository: _FakeFeedRepository(
          postsError: Exception('network error'),
        ),
      );

      await controller.loadPosts();

      expect(controller.posts, isEmpty);
      expect(controller.errorMessage, 'Unable to load feed right now.');
      expect(controller.isLoading, isFalse);
    });

    test('changeScope reloads posts with selected scope', () async {
      final repository = _FakeFeedRepository(posts: const <Post>[]);
      final controller = FeedController(feedRepository: repository);

      await controller.changeScope(FeedScope.global);

      expect(controller.selectedScope, FeedScope.global);
      expect(repository.lastScope, FeedScope.global);
    });

    test('followSuggestion removes suggestion on success', () async {
      final repository = _FakeFeedRepository(
        posts: const <Post>[],
        suggestions: const [
          FollowSuggestion(id: 'target-user', userName: 'sarah'),
        ],
      );
      final controller = FeedController(feedRepository: repository);
      await controller.loadPosts();

      final success = await controller.followSuggestion(
        controller.suggestions.first,
      );

      expect(success, isTrue);
      expect(repository.lastFollowedUserId, 'target-user');
      expect(controller.suggestions, isEmpty);
    });

    test('likePost updates selected post', () async {
      final repository = _FakeFeedRepository(
        posts: const [
          Post(
            id: 'post-1',
            userId: 'user-1',
            userName: 'Hugo',
            timestamp: 'Now',
            title: 'Selected',
            distance: '1000 m',
            duration: '5m',
            avgSplit: '2:30',
            strokeRate: '24',
            likes: 1,
          ),
        ],
        likeResult: const Post(
          id: 'post-1',
          userId: 'user-1',
          userName: 'Hugo',
          timestamp: 'Now',
          title: 'Selected',
          distance: '1000 m',
          duration: '5m',
          avgSplit: '2:30',
          strokeRate: '24',
          likes: 2,
        ),
      );
      final controller = FeedController(feedRepository: repository);
      await controller.loadPosts();
      controller.selectPost(controller.posts.first);

      final success = await controller.likePost(controller.posts.first);

      expect(success, isTrue);
      expect(controller.posts.first.likes, 2);
      expect(controller.selectedPost?.likes, 2);
    });

    test('selectPost sets selected post and clearSelectedPost clears it', () {
      final controller = FeedController(
        feedRepository: _FakeFeedRepository(posts: const []),
      );
      const post = Post(
        id: 'post-1',
        userId: 'user-1',
        userName: 'Hugo',
        timestamp: 'Now',
        title: 'Selected',
        distance: '1000 m',
        duration: '5m',
        avgSplit: '2:30',
        strokeRate: '24',
      );

      controller.selectPost(post);
      expect(controller.selectedPost, post);

      controller.clearSelectedPost();
      expect(controller.selectedPost, isNull);
    });
  });
}
