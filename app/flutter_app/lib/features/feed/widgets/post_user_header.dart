import 'package:flutter/material.dart';

class PostUserHeader extends StatelessWidget {
  final String name;
  final String timeAgo;

  const PostUserHeader({super.key, required this.name, required this.timeAgo});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          backgroundColor: Colors.grey,
          child: Icon(Icons.person, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(timeAgo, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        const Spacer(),
        const Icon(Icons.more_horiz, color: Colors.grey),
      ],
    );
  }
}