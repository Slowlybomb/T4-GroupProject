import 'package:flutter/material.dart';
import '../../feed/view/feed_screen.dart';
import '../../profile/view/profile_screen.dart';
import '../../activity_detail/view/detail_screen.dart';

class MainNavigationHub extends StatefulWidget {
  const MainNavigationHub({super.key});
  @override
  State<MainNavigationHub> createState() => _MainNavigationHubState();
}

class _MainNavigationHubState extends State<MainNavigationHub> {
  int _currentIndex = 0;
  bool _showDetails = false;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      FeedScreen(onPostTap: () => setState(() => _showDetails = true)),
      const UserStatsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _screens[_currentIndex],
          if (_showDetails)
            PostDetailScreen(onClose: () => setState(() => _showDetails = false)),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            _showDetails = false;
          });
        },
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Stats'),
        ],
      ),
    );
  }
}