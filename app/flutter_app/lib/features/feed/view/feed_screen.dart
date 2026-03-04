import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/post_stats_row.dart';
import '../controller/feed_controller.dart';
import '../domain/models/feed_scope.dart';
import '../domain/models/post.dart';
import '../widgets/activity_post_card.dart';
import '../widgets/filter_tabs.dart';
import '../widgets/weekly_summary_card.dart';
import '../widgets/who_to_follow_section.dart';
import '../../ble/view/ble_session_screen.dart';
import '../../profile/view/user_profile_screen.dart';

// ─── Hardcoded "Your Posts" data ─────────────────────────────────────────────
const _kYourPosts = [
  Post(
    userName: 'You',
    timestamp: '2 days ago',
    title: 'Morning row on the Liffey',
    distance: '8.4 km',
    duration: '42:15',
    avgSplit: '2:31',
    strokeRate: '22 spm',
    likes: 14,
  ),
  Post(
    userName: 'You',
    timestamp: '5 days ago',
    title: 'Evening session',
    distance: '5.2 km',
    duration: '27:40',
    avgSplit: '2:39',
    strokeRate: '20 spm',
    likes: 8,
  ),
  Post(
    userName: 'You',
    timestamp: '1 week ago',
    title: 'Long distance training',
    distance: '14.1 km',
    duration: '1:12:08',
    avgSplit: '2:33',
    strokeRate: '21 spm',
    likes: 31,
  ),
];

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Consumer<FeedController>(
        builder: (context, controller, child) {
          final slivers = <Widget>[
            SliverToBoxAdapter(
              child: _MainHeader(
                  onTabChanged: (i) => setState(() => _selectedTab = i)),
            ),
          ];

          if (_selectedTab == 2) {
            // ── Your Posts tab ────────────────────────────────────────────
            slivers.add(const SliverToBoxAdapter(child: _BleConnectCard()));
            slivers.add(SliverList(
              delegate: SliverChildListDelegate(
                _kYourPosts
                    .map((p) => ActivityPostCard(
                          post: p,
                          onAvatarTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  UserProfileScreen(name: p.userName),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ));
          } else if (_selectedTab == 1) {
            // ── Discover tab ──────────────────────────────────────────────
            slivers.add(_buildFeedContent(
              context: context,
              posts: _kDiscoverPosts,
              onPostTap: controller.selectPost,
              showWhoToFollow: false,
            ));
          } else {
            // ── Following tab ─────────────────────────────────────────────
            slivers.add(
                const SliverToBoxAdapter(child: WeeklySummaryCard()));
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
                onPostTap: controller.selectPost,
                showWhoToFollow: true,
              ));
            }
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
  }) {
    final children = <Widget>[];
    var insertedWhoToFollow = false;

    for (var index = 0; index < posts.length; index++) {
      if (index == 2) {
        children.add(const WhoToFollowSection());
        insertedWhoToFollow = true;
      }

      final post = posts[index];
      children.add(InkWell(
        onTap: () => onPostTap(post),
        child: ActivityPostCard(
          post: post,
          onAvatarTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(name: post.userName),
            ),
          ),
        ),
      );
    }

    if (!insertedWhoToFollow) children.add(const WhoToFollowSection());

    return SliverList(delegate: SliverChildListDelegate(children));
  }
}

// ─── BLE connect card ─────────────────────────────────────────────────────────
class _BleConnectCard extends StatelessWidget {
  const _BleConnectCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bluetooth, color: Colors.blue, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connect to Gondolier',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                SizedBox(height: 4),
                Text(
                  'Sync your latest rowing session',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BleScanScreen()),
            ),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _MainHeader extends StatelessWidget {
  final ValueChanged<int> onTabChanged;
  const _MainHeader({required this.onTabChanged});

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
          FilterTabs(onTabChanged: onTabChanged),
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
