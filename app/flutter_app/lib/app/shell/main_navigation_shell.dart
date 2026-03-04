import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/auth_repository.dart';
import '../../features/activity_detail/view/detail_screen.dart';
import '../../features/feed/controller/feed_controller.dart';
import '../../features/feed/view/feed_screen.dart';
import '../../features/profile/view/profile_screen.dart';
import '../../features/profile/view/user_profile_screen.dart';

class MainNavigationHub extends StatefulWidget {
  final AuthRepository? authRepository;

  const MainNavigationHub({super.key, this.authRepository});

  @override
  State<MainNavigationHub> createState() => _MainNavigationHubState();
}

class _MainNavigationHubState extends State<MainNavigationHub> {
  int _currentIndex = 0;

  void _switchToStatsTab() {
    setState(() => _currentIndex = 1);
  }

  void _showComingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      FeedScreen(onViewProgress: _switchToStatsTab),
      UserStatsScreen(authRepository: widget.authRepository),
    ];

    return Consumer<FeedController>(
      builder: (context, feedController, child) {
        return Scaffold(
          body: Stack(
            children: [
              screens[_currentIndex],
              if (feedController.selectedPost != null)
                PostDetailScreen(
                  post: feedController.selectedPost!,
                  onClose: feedController.clearSelectedPost,
                  onLike: (post) async {
                    final success = await feedController.likePost(post);
                    if (!success && context.mounted) {
                      _showComingSoon(
                        context,
                        'Unable to like this activity right now.',
                      );
                    }
                  },
                  onComment: () {
                    _showComingSoon(context, 'Comments are coming soon.');
                  },
                  onShare: () {
                    _showComingSoon(context, 'Share is coming soon.');
                  },
                  onAvatarTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(
                        name: feedController.selectedPost!.userName,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() => _currentIndex = index);
              feedController.clearSelectedPost();
            },
            selectedItemColor: Colors.red,
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Feed',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Stats',
              ),
            ],
          ),
        );
      },
    );
  }
}
