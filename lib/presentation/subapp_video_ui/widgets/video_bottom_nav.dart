import 'package:flutter/material.dart';
import '../../ui_theme.dart';
import '../video_library_screen.dart';

class VideoBottomNav extends StatelessWidget {
  final VideoTab currentTab;
  final Function(VideoTab) onTabSelected;

  const VideoBottomNav({super.key, required this.currentTab, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: isDark ? ArgusColors.bgDark.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
        border: Border(top: BorderSide(color: isDark ? ArgusColors.surfaceDark : Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(context, 'Video', Icons.play_circle, VideoTab.video),
          _buildNavItem(context, 'Browse', Icons.folder_copy, VideoTab.browse),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, String label, IconData icon, VideoTab tab) {
    final isActive = currentTab == tab;
    return GestureDetector(
      onTap: () => onTabSelected(tab),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? ArgusColors.primary.withValues(alpha: 0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: isActive ? ArgusColors.primary : Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? ArgusColors.primary : Colors.grey,
            ),
          )
        ],
      ),
    );
  }
}
