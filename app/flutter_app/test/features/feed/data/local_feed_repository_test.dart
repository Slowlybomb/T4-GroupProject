import 'package:flutter_test/flutter_test.dart';
import 'package:gondolier/features/feed/data/local_feed_repository.dart';

void main() {
  group('LocalFeedRepository', () {
    test('returns deterministic local posts', () async {
      const repository = LocalFeedRepository();

      final posts = await repository.getPosts();

      expect(posts, isNotEmpty);
      expect(posts.first.userName, 'Hugo');
      expect(posts.first.title, 'Hard session on the ergometer today!');
    });
  });
}
