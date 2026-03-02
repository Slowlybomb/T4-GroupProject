import '../data/repositories/user_repository.dart';
import '../data/repositories/feed_repository.dart';

// Simple service locator
class Locator {
  static final UserRepository userRepository = UserRepository();
  static final FeedRepository feedRepository = FeedRepository();
}