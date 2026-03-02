// TODO: Implement profile_screen.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colour_theme.dart';

class UserStatsScreen extends StatelessWidget {
  const UserStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text("You", style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: const [
          Padding(
            padding: EdgeInsets.all(8.0), 
            child: CircleAvatar(backgroundColor: Colors.grey, radius: 15)
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const _ThisWeekSummary(),
            const Text("More graphs", style: TextStyle(fontSize: 40, fontWeight: FontWeight.w300)),
            const _TrainingLogCard(),
          ],
        ),
      ),
    );
  }
}

// Internal helpers for the Profile Screen
class _ThisWeekSummary extends StatelessWidget {
  const _ThisWeekSummary();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("This Week", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          Row(
            children: [
              Text("Distance: 0 km  ", style: TextStyle(color: AppColors.textGrey)),
              Text("Time: 0 m", style: TextStyle(color: AppColors.textGrey)),
            ],
          ),
          SizedBox(height: 100, child: Center(child: Text("--- Graph Placeholder ---"))),
        ],
      ),
    );
  }
}

class _TrainingLogCard extends StatelessWidget {
  const _TrainingLogCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryRed, 
        borderRadius: BorderRadius.circular(20)
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Training Log", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text("Feb 2 - Feb 8, 2026", style: TextStyle(color: Colors.white70, fontSize: 12)),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              CircleAvatar(radius: 15, backgroundColor: Colors.white24, child: Text("M", style: TextStyle(color: Colors.white, fontSize: 10))),
              CircleAvatar(radius: 15, backgroundColor: Colors.white24, child: Text("T", style: TextStyle(color: Colors.white, fontSize: 10))),
              CircleAvatar(radius: 20, backgroundColor: Colors.white, child: Text("1h", style: TextStyle(color: AppColors.primaryRed, fontSize: 12, fontWeight: FontWeight.bold))),
              CircleAvatar(radius: 15, backgroundColor: Colors.white24, child: Text("T", style: TextStyle(color: Colors.white, fontSize: 10))),
            ],
          )
        ],
      ),
    );
  }
}