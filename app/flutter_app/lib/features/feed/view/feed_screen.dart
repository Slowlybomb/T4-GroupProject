import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/feed_controller.dart';
import '../domain/models/feed_scope.dart';
import '../domain/models/post.dart';
import '../widgets/activity_post_card.dart';
import '../widgets/filter_tabs.dart';
import '../widgets/weekly_summary_card.dart';
import '../widgets/who_to_follow_section.dart';
import '../../profile/view/user_profile_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.onViewProgress});

  final VoidCallback onViewProgress;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
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
                onScopeSelected: (scope) {
                  controller.changeScope(scope);
                },
              ),
            ),
            SliverToBoxAdapter(
              child: WeeklySummaryCard(
                summary: controller.weeklySummary,
                isLoading: controller.isLoading,
                errorMessage: controller.summaryErrorMessage,
                onViewProgress: widget.onViewProgress,
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
                onPostTap: controller.selectPost,
                showWhoToFollow:
                    controller.selectedScope == FeedScope.following,
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
    required ValueChanged<Post> onPostTap,
    required bool showWhoToFollow,
  }) {
    final children = <Widget>[];
    var insertedWhoToFollow = false;

    for (var index = 0; index < posts.length; index++) {
      if (showWhoToFollow && index == 2) {
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
              return success;
            },
          ),
        );
        insertedWhoToFollow = true;
      }

      final post = posts[index];
      children.add(
        InkWell(
          onTap: () => onPostTap(post),
          child: ActivityPostCard(
            post: post,
            onAvatarTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(name: post.userName),
              ),
            ),
            onLikeTap: () async {
              final success = await controller.likePost(post);
              if (!success && context.mounted) {
                _showSnack(context, 'Unable to like this activity right now.');
              }
            },
            onCommentTap: () {
              _showSnack(context, 'Comments are coming soon.');
            },
            onShareTap: () {
              _showSnack(context, 'Share is coming soon.');
            },
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
            return success;
          },
        ),
      );
    }

    return SliverList(delegate: SliverChildListDelegate(children));
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _MainHeader extends StatefulWidget {
  const _MainHeader({
    required this.selectedScope,
    required this.onScopeSelected,
  });

  final FeedScope selectedScope;
  final ValueChanged<FeedScope> onScopeSelected;

  @override
  State<_MainHeader> createState() => _MainHeaderState();
}

class _MainHeaderState extends State<_MainHeader> {
  bool _notificationsOn = true;

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
                children: [
                  const Text(
                    'Home',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      _notificationsOn
                          ? Icons.notifications
                          : Icons.notifications_off_outlined,
                      color: Colors.red,
                    ),
                    onPressed: () {
                      setState(() => _notificationsOn = !_notificationsOn);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _notificationsOn
                                ? 'Notifications on'
                                : 'Notifications off',
                          ),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilterTabs(
            selectedScope: widget.selectedScope,
            onScopeSelected: widget.onScopeSelected,
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
