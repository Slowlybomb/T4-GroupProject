import '../domain/models/post.dart';

abstract class FeedRepository {
  Future<List<Post>> getPosts();
}
