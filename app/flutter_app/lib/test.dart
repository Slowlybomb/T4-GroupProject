import 'package:flutter/material.dart';

void main() => runApp(const RowingApp());

class RowingApp extends StatelessWidget {
  const RowingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.red, fontFamily: 'sans-serif'),
      home: const FeedScreen(),
    );
  }
}

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          // Header Area
          const SliverToBoxAdapter(child: MainHeader()),
          
          // Weekly Summary Card
          const SliverToBoxAdapter(child: WeeklySummaryCard()),

          // The Feed List
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                // Insert "Who to Follow" after the second post
                if (index == 2) return const WhoToFollowSection();
                return const ActivityPostCard();
              },
              childCount: 5,
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.perm_identity), label: 'Perm Identity'),
        ],
      ),
    );
  }
}

class MainHeader extends StatelessWidget {
  const MainHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.network('https://cdn-icons-png.flaticon.com/512/2910/2910793.png', height: 40), // Placeholder logo
              Row(
                children: [
                  const Text('Home', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 15),
                  const Icon(Icons.notifications_none, color: Colors.red),
                  const SizedBox(width: 15),
                  const Icon(Icons.account_circle, color: Colors.red),
                  const SizedBox(width: 15),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: const [
              Text('Following', style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline, decorationColor: Colors.red, decorationThickness: 2)),
              SizedBox(width: 20),
              Text('You', style: TextStyle(color: Colors.grey)),
              SizedBox(width: 20),
              Text('Discover', style: TextStyle(color: Colors.grey)),
            ],
          )
        ],
      ),
    );
  }
}

class WeeklySummaryCard extends StatelessWidget {
  const WeeklySummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekly Summary', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Distance', style: TextStyle(color: Colors.white70)),
                    Text('48.9 km', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Activities', style: TextStyle(color: Colors.white70)),
                    Text('4', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red,
                shape: const StadiumBorder(),
              ),
              child: const Text('View progress', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}

class ActivityPostCard extends StatelessWidget {
  const ActivityPostCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(backgroundColor: Colors.grey),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('My name is Hugo', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('2h ago', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              const Spacer(),
              const Icon(Icons.more_horiz),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Text('Shit myself while rowing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              StatItem(label: 'Distance', value: '33.2km'),
              StatItem(label: 'Time', value: '1h 12m'),
              StatItem(label: 'Avg', value: '1h 12m'),
              StatItem(label: 'Split', value: '1h 12m'),
            ],
          ),
          const SizedBox(height: 15),
          // Map Placeholder
          Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
             
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.favorite_border, color: Colors.red),
              const SizedBox(width: 15),
              const Icon(Icons.chat_bubble_outline, color: Colors.red),
              const Spacer(),
              const Icon(Icons.share_outlined, color: Colors.red),
            ],
          )
        ],
      ),
    );
  }
}

class StatItem extends StatelessWidget {
  final String label, value;
  const StatItem({super.key, required this.label, required this.value});

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

class WhoToFollowSection extends StatelessWidget {
  const WhoToFollowSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Who to Follow:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text('See All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: 5,
            itemBuilder: (context, index) => const FollowCard(),
          ),
        )
      ],
    );
  }
}

class FollowCard extends StatelessWidget {
  const FollowCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 15, bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const CircleAvatar(radius: 30, backgroundColor: Colors.grey),
          const SizedBox(height: 10),
          const Text('Peter McQualere', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
          const Text('10 friends in common', style: TextStyle(fontSize: 10, color: Colors.grey)),
          const Spacer(),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 30)),
            child: const Text('Follow', style: TextStyle(fontSize: 12)),
          )
        ],
      ),
    );
  }
}