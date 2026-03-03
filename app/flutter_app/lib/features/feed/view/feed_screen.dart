import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/feed_controller.dart';
import '../domain/models/post.dart';
import '../widgets/activity_post_card.dart';
import '../widgets/filter_tabs.dart';
import '../widgets/weekly_summary_card.dart';
import '../widgets/who_to_follow_section.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Consumer<FeedController>(
        builder: (context, controller, child) {
          // Build the static header first; dynamic content sliver is appended below.
          final slivers = <Widget>[
            const SliverToBoxAdapter(child: _MainHeader()),
            const SliverToBoxAdapter(child: WeeklySummaryCard()),
          ];

          // Keep previous UX semantics: spinner/error/empty only fill when no data.
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
          } else {
            if (controller.posts.isEmpty) {
              slivers.add(
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _FeedEmptyState(),
                ),
              );
            } else {
              slivers.add(
                _buildFeedContent(
                  posts: controller.posts,
                  onPostTap: controller.selectPost,
                ),
              );
            }
          }

          return CustomScrollView(slivers: slivers);
        },
      ),
    );
  }

  Widget _buildFeedContent({
    required List<Post> posts,
    required ValueChanged<Post> onPostTap,
  }) {
    final children = <Widget>[];
    var insertedWhoToFollow = false;

    for (var index = 0; index < posts.length; index++) {
      // Preserve existing design where suggestions are injected after 2 posts.
      if (index == 2) {
        children.add(const WhoToFollowSection());
        insertedWhoToFollow = true;
      }

      final post = posts[index];
      children.add(
        InkWell(
          onTap: () => onPostTap(post),
          child: ActivityPostCard(post: post),
        ),
      );
    }

    if (!insertedWhoToFollow) {
      children.add(const WhoToFollowSection());
    }

    return SliverList(delegate: SliverChildListDelegate(children));
  }
}

class _MainHeader extends StatelessWidget {
  const _MainHeader();

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
          const FilterTabs(),
        ],
      ),
    );
  }
}

class _FeedErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _FeedErrorState({required this.onRetry});

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
