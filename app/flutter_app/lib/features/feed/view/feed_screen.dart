import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/feed_controller.dart';
import '../domain/models/feed_scope.dart';
import '../domain/models/post.dart';
import '../widgets/activity_post_card.dart';
import '../widgets/filter_tabs.dart';
import '../widgets/weekly_summary_card.dart';
import '../widgets/who_to_follow_section.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key, this.onViewProgress});

  final VoidCallback? onViewProgress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Consumer<FeedController>(
        builder: (context, controller, child) {
          final slivers = <Widget>[
            SliverToBoxAdapter(
              child: _MainHeader(
                selectedScope: controller.selectedScope,
                onScopeSelected: controller.changeScope,
              ),
            ),
            SliverToBoxAdapter(
              child: WeeklySummaryCard(
                summary: controller.weeklySummary,
                isLoading: controller.isLoading,
                errorMessage: controller.summaryErrorMessage,
                onViewProgress: onViewProgress ?? () {},
              ),
            ),
          ];

          if (controller.isLoading && controller.posts.isEmpty) {
            slivers.add(
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          } else if (controller.errorMessage != null &&
              controller.posts.isEmpty) {
            slivers.add(
              SliverFillRemaining(
                hasScrollBody: false,
                child: _FeedErrorState(onRetry: controller.loadPosts),
              ),
            );
          } else if (controller.posts.isEmpty) {
            slivers.add(
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _FeedEmptyState(),
              ),
            );
          } else {
            slivers.add(
              _buildFeedContent(
                context: context,
                controller: controller,
                posts: controller.posts,
              ),
            );
          }

          return CustomScrollView(slivers: slivers);
        },
      ),
    );
  }

  Widget _buildFeedContent({
    required BuildContext context,
    required FeedController controller,
    required List<Post> posts,
  }) {
    final children = <Widget>[];
    var insertedWhoToFollow = false;

    for (var index = 0; index < posts.length; index++) {
      if (index == 2) {
        children.add(
          WhoToFollowSection(
            suggestions: controller.suggestions,
            errorMessage: controller.suggestionsErrorMessage,
            isFollowing: controller.isFollowing,
            onFollowTap: (suggestion) async {
              final success = await controller.followSuggestion(suggestion);
              if (!success && context.mounted) {
                _showSnack(context, 'Unable to follow user right now.');
              }
            },
          ),
        );
        insertedWhoToFollow = true;
      }

      final post = posts[index];
      children.add(
        InkWell(
          onTap: () => controller.selectPost(post),
          child: ActivityPostCard(
            post: post,
            onLikeTap: () async {
              final success = await controller.likePost(post);
              if (!success && context.mounted) {
                _showSnack(context, 'Unable to like this activity right now.');
              }
            },
            onCommentTap: () =>
                _showSnack(context, 'Comments are coming soon.'),
            onShareTap: () => _showSnack(context, 'Share is coming soon.'),
          ),
        ),
      );
    }

    if (!insertedWhoToFollow) {
      children.add(
        WhoToFollowSection(
          suggestions: controller.suggestions,
          errorMessage: controller.suggestionsErrorMessage,
          isFollowing: controller.isFollowing,
          onFollowTap: (suggestion) async {
            final success = await controller.followSuggestion(suggestion);
            if (!success && context.mounted) {
              _showSnack(context, 'Unable to follow user right now.');
            }
          },
        ),
      );
    }

    return SliverList(delegate: SliverChildListDelegate(children));
  }

  static void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MainHeader extends StatelessWidget {
  const _MainHeader({
    required this.selectedScope,
    required this.onScopeSelected,
  });

  final FeedScope selectedScope;
  final Future<void> Function(FeedScope scope) onScopeSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                height: 60,
                width: 60,
                child: Image.asset('assets/img/logo-gondolier.png'),
              ),
              Row(
                children: const [
                  Text(
                    'Home',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 15),
                  Icon(Icons.notifications_none, color: Colors.red),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilterTabs(
            selectedScope: selectedScope,
            onScopeSelected: (scope) => onScopeSelected(scope),
          ),
        ],
      ),
    );
  }
}

class _FeedErrorState extends StatelessWidget {
  const _FeedErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Unable to load feed right now.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please check your connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _FeedEmptyState extends StatelessWidget {
  const _FeedEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No activities yet',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }
}
