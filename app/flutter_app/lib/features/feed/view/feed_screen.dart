// TODO: Implement feed_screen.dart
import 'package:flutter/material.dart';
import '../widgets/weekly_summary_card.dart';
import '../widgets/activity_post_card.dart';
import '../widgets/who_to_follow_section.dart'; // Create this similarly
import '../widgets/filter_tabs.dart'; // Create this similarly
class FeedScreen extends StatelessWidget {
  final VoidCallback onPostTap;
  const FeedScreen({super.key, required this.onPostTap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _MainHeader()),
          const SliverToBoxAdapter(child: WeeklySummaryCard()),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == 2) return const WhoToFollowSection();
                return InkWell(
                  onTap: onPostTap,
                  child: const ActivityPostCard(),
                );
              },
              childCount: 10,
            ),
          )
        ],
      ),
    );
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
              const Icon(Icons.waves, color: Colors.red, size: 30),
              Row(
                children: const [
                  Text('Home', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  SizedBox(width: 15),
                  Icon(Icons.notifications_none, color: Colors.red),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          const FilterTabs(),
        ],
      ),
    );
  }
}