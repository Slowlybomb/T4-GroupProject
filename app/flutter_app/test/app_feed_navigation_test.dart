import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gondolier/app/shell/main_navigation_shell.dart';
import 'package:gondolier/features/activity_detail/view/detail_screen.dart';
import 'package:gondolier/features/feed/controller/feed_controller.dart';
import 'package:gondolier/features/feed/data/feed_repository.dart';
import 'package:gondolier/features/feed/domain/models/feed_scope.dart';
import 'package:gondolier/features/feed/domain/models/follow_suggestion.dart';
import 'package:gondolier/features/feed/domain/models/post.dart';
import 'package:gondolier/features/feed/domain/models/weekly_summary.dart';
import 'package:provider/provider.dart';

import 'support/fake_auth_repository.dart';

class _StubFeedRepository implements FeedRepository {
  final List<Post> _posts;

  const _StubFeedRepository(this._posts);

  @override
  Future<List<Post>> getPosts({FeedScope scope = FeedScope.following}) async =>
      _posts;

  @override
  Future<WeeklySummary> getWeeklySummary({
    required DateTime from,
    required DateTime to,
  }) async {
    return WeeklySummary(
      from: from,
      to: to,
      totalActivities: _posts.length,
      totalDistanceKm: 10,
    );
  }

  @override
  Future<List<FollowSuggestion>> getFollowSuggestions({int limit = 5}) async {
    return const [];
  }

  @override
  Future<void> followUser(String userId) async {}

  @override
  Future<Post> likePost(String postId) async {
    final post = _posts.firstWhere((candidate) => candidate.id == postId);
    return post.copyWith(likes: post.likes + 1);
  }
}

const _stubPosts = <Post>[
  Post(
    id: 'post-1',
    userId: 'user-1',
    userName: 'Hugo',
    timestamp: '22 Jan 2026 - Cork',
    title: 'Hard session on the ergometer today!',
    distance: '33200 m',
    duration: '1h 12m',
    avgSplit: '2:10',
    strokeRate: '24',
    likes: 12,
  ),
  Post(
    id: 'post-2',
    userId: 'user-2',
    userName: 'Sarah',
    timestamp: '22 Jan 2026 - Cork',
    title: 'Morning 5k piece, feeling strong.',
    distance: '5000 m',
    duration: '18m 30s',
    avgSplit: '1:51',
    strokeRate: '28',
    likes: 8,
  ),
];

Future<void> _pumpShell(WidgetTester tester) async {
  final authRepository = FakeAuthRepository(isLoggedIn: true);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<FeedRepository>(
          create: (_) => const _StubFeedRepository(_stubPosts),
        ),
        ChangeNotifierProvider<FeedController>(
          create: (context) =>
              FeedController(feedRepository: context.read<FeedRepository>())
                ..loadPosts(),
        ),
      ],
      child: MaterialApp(
        home: MainNavigationHub(authRepository: authRepository),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  group('MainNavigationHub feed/detail behavior', () {
    testWidgets('post tap opens detail and close hides it', (tester) async {
      await _pumpShell(tester);

      expect(find.text('Hard session on the ergometer today!'), findsOneWidget);
      expect(find.byType(PostDetailScreen), findsNothing);

      await tester.tap(find.text('Hard session on the ergometer today!'));
      await tester.pumpAndSettle();

      expect(find.byType(PostDetailScreen), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(PostDetailScreen), findsNothing);
    });

    testWidgets(
      'switching tabs closes detail and returning to feed preserves feed list',
      (tester) async {
        await _pumpShell(tester);

        await tester.tap(find.text('Hard session on the ergometer today!'));
        await tester.pumpAndSettle();
        expect(find.byType(PostDetailScreen), findsOneWidget);

        await tester.tap(find.text('Stats'));
        await tester.pumpAndSettle();
        expect(find.byType(PostDetailScreen), findsNothing);
        expect(find.text('Account details'), findsOneWidget);

        await tester.tap(find.text('Feed'));
        await tester.pumpAndSettle();
        expect(find.byType(PostDetailScreen), findsNothing);
        expect(
          find.text('Hard session on the ergometer today!'),
          findsOneWidget,
        );
      },
    );
  });
}
