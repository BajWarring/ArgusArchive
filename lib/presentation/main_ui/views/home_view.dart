import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ui_theme.dart';
import '../../debug_ui/providers.dart';

class HomeView extends ConsumerWidget {
  final VoidCallback onOpenStorage;
  
  const HomeView({super.key, required this.onOpenStorage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildSectionHeader('PINNED FOLDERS'),
        _buildPinnedFolders(ref),
        const SizedBox(height: 16),
        _buildSectionHeader('STORAGE DEVICES'),
        _buildStorageDevices(context, ref),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ArgusColors.slate500, letterSpacing: 1.2)),
    );
  }

  Widget _buildPinnedFolders(WidgetRef ref) {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildPinnedCard('Downloads', '12 items', () {
             ref.read(currentPathProvider.notifier).state = '/storage/emulated/0/Download';
             onOpenStorage();
          }),
          _buildAddPinCard(),
        ],
      ),
    );
  }

  Widget _buildPinnedCard(String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white, // Matches light HTML
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.folder, color: ArgusColors.primary, size: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: ArgusColors.slate500)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAddPinCard() {
    return Container(
      width: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3), style: BorderStyle.solid, width: 2),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle, color: ArgusColors.slate500, size: 28),
          SizedBox(height: 4),
          Text('Pin Folder', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ArgusColors.slate500)),
        ],
      ),
    );
  }

  Widget _buildStorageDevices(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 140,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildStorageCard(context, 'Internal Storage', 'Local Device', Icons.smartphone, true, () {
             ref.read(currentPathProvider.notifier).state = '/storage/emulated/0';
             onOpenStorage();
          }),
          _buildStorageCard(context, 'SD Card', 'External Media', Icons.sd_card, false, () {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SD Card access via debug_ui paths.')));
          }),
        ],
      ),
    );
  }

  Widget _buildStorageCard(BuildContext context, String title, String subtitle, IconData icon, bool isPrimary, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: isPrimary ? ArgusColors.primary.withValues(alpha: 0.1) : Colors.blueGrey.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: isPrimary ? ArgusColors.primary : Colors.blueGrey),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: ArgusColors.slate500)),
              ],
            )
          ],
        ),
      ),
    );
  }
}
