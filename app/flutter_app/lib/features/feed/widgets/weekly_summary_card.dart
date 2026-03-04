import 'package:flutter/material.dart';
import '../../../core/theme/app_colour_theme.dart';
import '../../activity_detail/view/detail_screen.dart';
import '../../feed/domain/models/post.dart';
import '../../stats/view/weekly_progress_screen.dart';

const _kWeeklyPosts = [
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

class WeeklySummaryCard extends StatelessWidget {
  const WeeklySummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Static summary block used while richer stats integration is in progress.
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryRed,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: const [
              Expanded(
                child: _SummaryStat(label: 'Distance', value: '48.9 km'),
              ),
              Expanded(
                child: _SummaryStat(label: 'Activities', value: '5'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeeklyProgressScreen())),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red,
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'View progress',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
        ],
      ),
    );
  }
}

class _WeeklyPostCard extends StatelessWidget {
  final Post post;
  const _WeeklyPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(
            post: post,
            onClose: () => Navigator.pop(context),
          ),
        ),
      ),
      child: Container(
        width: 155,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              post.distance,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              post.timestamp,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label, value;
  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
