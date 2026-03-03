import 'package:flutter/material.dart';

import '../../../core/locator.dart';
import '../../../data/models/activity_model.dart';
import '../widgets/activity_post_card.dart';
import '../widgets/filter_tabs.dart';
import '../widgets/weekly_summary_card.dart';
import '../widgets/who_to_follow_section.dart';

class FeedScreen extends StatefulWidget {
  final VoidCallback onPostTap;

  const FeedScreen({super.key, required this.onPostTap});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late Future<List<ActivityModel>> _activitiesFuture;

  @override
  void initState() {
    super.initState();
    _activitiesFuture = _loadActivities();
  }

  Future<List<ActivityModel>> _loadActivities() {
    return Locator.feedRepository.getFeedActivities();
  }

  void _reloadFeed() {
    setState(() {
      _activitiesFuture = _loadActivities();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: FutureBuilder<List<ActivityModel>>(
        future: _activitiesFuture,
        builder: (context, snapshot) {
          final slivers = <Widget>[
            const SliverToBoxAdapter(child: _MainHeader()),
            const SliverToBoxAdapter(child: WeeklySummaryCard()),
          ];

          if (snapshot.connectionState == ConnectionState.waiting) {
            slivers.add(
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          } else if (snapshot.hasError) {
            slivers.add(
              SliverFillRemaining(
                hasScrollBody: false,
                child: _FeedErrorState(onRetry: _reloadFeed),
              ),
            );
          } else {
            final activities = snapshot.data ?? const <ActivityModel>[];
            if (activities.isEmpty) {
              slivers.add(
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _FeedEmptyState(),
                ),
              );
            } else {
              slivers.add(_buildFeedContent(activities));
            }
          }

          return CustomScrollView(slivers: slivers);
        },
      ),
    );
  }

  Widget _buildFeedContent(List<ActivityModel> activities) {
    final children = <Widget>[];
    var insertedWhoToFollow = false;

    for (var index = 0; index < activities.length; index++) {
      if (index == 2) {
        children.add(const WhoToFollowSection());
        insertedWhoToFollow = true;
      }

      final activity = activities[index];
      children.add(
        InkWell(
          onTap: widget.onPostTap,
          child: ActivityPostCard(activity: activity),
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
                height: 40,
                width: 40,
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
