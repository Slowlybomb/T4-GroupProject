import '../domain/models/post.dart';
import 'feed_repository.dart';

class LocalFeedRepository implements FeedRepository {
  const LocalFeedRepository();

  @override
  Future<List<Post>> getPosts() async {
    return const [
      Post(
        userName: 'Hugo',
        avatarUrl: null,
        timestamp: '22 Jan 2026 - Cork',
        title: 'Hard session on the ergometer today!',
        distance: '33200 m',
        duration: '1h 12m',
        avgSplit: '2:10',
        strokeRate: '24',
        likes: 12,
      ),
      Post(
        userName: 'Sarah',
        avatarUrl: null,
        timestamp: '22 Jan 2026 - Cork',
        title: 'Morning 5k piece, feeling strong.',
        distance: '5000 m',
        duration: '18m 30s',
        avgSplit: '1:51',
        strokeRate: '28',
        likes: 8,
      ),
    ];
  }
}
