import 'package:flutter/material.dart';
import '../../ui_theme.dart';

class BrowseView extends StatelessWidget {
  final VoidCallback onOpenExplorer;

  const BrowseView({super.key, required this.onOpenExplorer});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildSectionHeader('FAVORITE FOLDERS'),
        _buildFavoriteFolders(),
        const SizedBox(height: 16),
        _buildSectionHeader('STORAGE DEVICES'),
        _buildStorageDevices(context),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildFavoriteFolders() {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFavCard('Camera', '142 videos', Icons.photo_camera, Colors.pink),
          _buildFavCard('Downloads', '28 videos', Icons.download, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildFavCard(String title, String subtitle, IconData icon, Color color) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ArgusColors.surfaceDark.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStorageDevices(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildStorageCard(context, 'Internal Storage', '10 GB used of 64 GB', Icons.smartphone, 0.15),
          const SizedBox(height: 12),
          _buildStorageCard(context, 'SD Card', '42 GB used of 64 GB', Icons.sd_card, 0.65),
        ],
      ),
    );
  }

  Widget _buildStorageCard(BuildContext context, String title, String subtitle, IconData icon, double progress) {
    return GestureDetector(
      onTap: onOpenExplorer,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ArgusColors.surfaceDark.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(radius: 24, backgroundColor: ArgusColors.primary.withValues(alpha: 0.1), child: Icon(icon, color: ArgusColors.primary, size: 24)),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(ArgusColors.primary),
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
            )
          ],
        ),
      ),
    );
  }
}
