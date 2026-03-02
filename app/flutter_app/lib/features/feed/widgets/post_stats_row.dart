import 'package:flutter/material.dart';

class PostStatsRow extends StatelessWidget {
  const PostStatsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        _StatTile(label: 'Distance', value: '33.2km'),
        _StatTile(label: 'Time', value: '1h 12m'),
        _StatTile(label: 'Avg Split', value: '2:10'),
        _StatTile(label: 'Strokes', value: '24 s/m'),
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
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}