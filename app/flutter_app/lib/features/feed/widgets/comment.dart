import 'package:flutter/material.dart';
class PostCommentsSheet extends StatelessWidget {
  const PostCommentsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: controller, // Essential for scrolling inside the sheet
                itemCount: 2, 
                itemBuilder: (context, index) => const ListTile(
                  leading: CircleAvatar(child: Icon(Icons.person)),
                  title: Text('User Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text('Nice rowing session!'),
                ),
              ),
            ),
            // Input field would go here
          ],
        ),
      ),
    );
  }
}