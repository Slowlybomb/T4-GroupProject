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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _StatTile(label: 'Distance', value: distance),
        _StatTile(label: 'Time', value: duration),
        _StatTile(label: 'Avg Split', value: avgSplit),
        _StatTile(label: 'Strokes', value: strokeRate),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label, value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
