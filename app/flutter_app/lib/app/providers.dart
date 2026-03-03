import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../core/locator.dart';
import '../features/feed/controller/feed_controller.dart';
import '../features/feed/data/api_feed_repository.dart';
import '../features/feed/data/feed_repository.dart';
import '../features/onboarding/controller/onboarding_controller.dart';

List<SingleChildWidget> createAppProviders(AppDependencies dependencies) {
  return [
    Provider<FeedRepository>(
      create: (_) => ApiFeedRepository(
        activityFeedRepository: dependencies.feedRepository,
      ),
    ),
    ChangeNotifierProvider<FeedController>(
      create: (context) =>
          FeedController(feedRepository: context.read<FeedRepository>())
            ..loadPosts(),
    ),
    ChangeNotifierProvider<OnboardingController>(
      create: (_) => OnboardingController(),
    ),
  ];
}
