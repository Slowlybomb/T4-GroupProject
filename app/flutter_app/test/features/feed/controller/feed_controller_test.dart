import 'package:flutter_test/flutter_test.dart';
import 'package:gondolier/features/feed/controller/feed_controller.dart';
import 'package:gondolier/features/feed/data/feed_repository.dart';
import 'package:gondolier/features/feed/domain/models/post.dart';

class _FakeFeedRepository implements FeedRepository {
  _FakeFeedRepository({this.posts = const <Post>[], this.error});

  final List<Post> posts;
  final Object? error;

  @override
  Future<List<Post>> getPosts() async {
    // Keep controller tests deterministic by controlling success/failure.
    if (error != null) {
      throw error!;
    }
    return posts;
  }
}

void main() {
  group('FeedController', () {
    test('loadPosts populates posts from repository', () async {
      final controller = FeedController(
        feedRepository: _FakeFeedRepository(
          posts: const [
            Post(
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
      expect(controller.isLoading, isFalse);
    });

    test('loadPosts exposes user-friendly error on failure', () async {
      final controller = FeedController(
        feedRepository: _FakeFeedRepository(error: Exception('network error')),
      );

      await controller.loadPosts();

      expect(controller.posts, isEmpty);
      expect(controller.errorMessage, 'Unable to load feed right now.');
      expect(controller.isLoading, isFalse);
    });

    test('selectPost sets selected post and clearSelectedPost clears it', () {
      final controller = FeedController(
        feedRepository: _FakeFeedRepository(posts: const []),
      );
      const post = Post(
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
