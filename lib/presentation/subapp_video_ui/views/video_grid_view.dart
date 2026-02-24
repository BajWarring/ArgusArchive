import 'package:flutter/material.dart';

class VideoGridView extends StatelessWidget {
  const VideoGridView({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Padding for bottom nav
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: 6, // Stub count matching HTML
      itemBuilder: (context, index) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.indigo.shade900,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: CircleAvatar(
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.play_arrow, color: Colors.white),
                      ),
                    ),
                    Positioned(
                      bottom: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                        child: const Text('12:45', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Cyberpunk_City_Render.mp4', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            const Text('850 MB • Oct 24', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        );
      },
    );
  }
}
