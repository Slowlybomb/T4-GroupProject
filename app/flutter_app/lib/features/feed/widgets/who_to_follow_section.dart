import 'package:flutter/material.dart';
import '../../../core/theme/app_colour_theme.dart';

class WhoToFollowSection extends StatelessWidget {
  const WhoToFollowSection({super.key});

  @override
  Widget build(BuildContext context) {
    // Demo suggestions stay local until backend "follow suggestions" API exists.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "Who to follow",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: 5,
            itemBuilder: (context, index) {
              return const _FollowerCard();
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _FollowerCard extends StatelessWidget {
  const _FollowerCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5),
        ],
      ),
      child: Column(
        children: [
          const CircleAvatar(backgroundColor: Colors.grey, radius: 25),
          const SizedBox(height: 10),
          const Text(
            "User",
            style: TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1,
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              shape: const StadiumBorder(),
              minimumSize: const Size(double.infinity, 30),
            ),
            child: const Text("Follow", style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
