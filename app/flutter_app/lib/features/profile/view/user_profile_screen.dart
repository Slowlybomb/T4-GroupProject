import 'package:flutter/material.dart';
import '../../../core/theme/app_colour_theme.dart';

class UserProfileScreen extends StatefulWidget {
  final String name;

  const UserProfileScreen({super.key, required this.name});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _following = false;

  // Hardcoded demo activities for any user profile
  static const _recentActivities = [
    _ActivityEntry(title: 'Morning row on the Liffey', distance: '8.4 km', date: '2 days ago'),
    _ActivityEntry(title: 'Evening session', distance: '5.2 km', date: '5 days ago'),
    _ActivityEntry(title: 'Long distance training', distance: '14.1 km', date: '1 week ago'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryRed,
        elevation: 0,
        title: Text(
          widget.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Profile header card ────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Joined March 2024',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: const [
                      _ProfileStat(label: 'Activities', value: '12'),
                      _VerticalDivider(),
                      _ProfileStat(label: 'Likes', value: '47'),
                      _VerticalDivider(),
                      _ProfileStat(label: 'Followers', value: '38'),
                      _VerticalDivider(),
                      _ProfileStat(label: 'Following', value: '21'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 160,
                    child: ElevatedButton(
                      onPressed: () => setState(() => _following = !_following),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _following ? Colors.grey.shade200 : AppColors.primaryRed,
                        foregroundColor:
                            _following ? AppColors.primaryRed : Colors.white,
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: Text(
                        _following ? 'Following' : 'Follow',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── Recent activities ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Activities',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ..._recentActivities.map((a) => _ActivityCard(entry: a)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────
class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: Colors.grey.shade200);
  }
}

class _ActivityEntry {
  final String title;
  final String distance;
  final String date;
  const _ActivityEntry({required this.title, required this.distance, required this.date});
}

class _ActivityCard extends StatelessWidget {
  final _ActivityEntry entry;
  const _ActivityCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.directions_boat_outlined,
                color: AppColors.primaryRed, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  '${entry.distance} · ${entry.date}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}
