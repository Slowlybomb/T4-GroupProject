import 'package:flutter/material.dart';

class PostStatsRow extends StatelessWidget {
  final String distance;
  final String duration;
  final String avgSplit;
  final String strokeRate;

  const PostStatsRow({
    super.key,
    this.distance = '--',
    this.duration = '--',
    this.avgSplit = '--',
    this.strokeRate = '--',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatTile(icon: Icons.directions_boat_outlined, label: 'Distance', value: distance),
          _Divider(),
          _StatTile(icon: Icons.timer_outlined, label: 'Time', value: duration),
          _Divider(),
          _StatTile(icon: Icons.speed_outlined, label: 'Avg Split', value: avgSplit),
          _Divider(),
          _StatTile(icon: Icons.rowing_outlined, label: 'Stroke Rate', value: strokeRate),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: Colors.grey.shade200);
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.red.shade400),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
