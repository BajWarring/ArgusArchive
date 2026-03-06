import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ui_theme.dart';

// In-memory preference providers (no persistence dependency required)
final resumePlaybackProvider = StateProvider<bool>((ref) => true);
final autoPlayNextProvider = StateProvider<bool>((ref) => false);
final loopVideoProvider = StateProvider<bool>((ref) => false);
final swipeGesturesProvider = StateProvider<bool>((ref) => true);
final darkModeProvider = StateProvider<bool>((ref) => true);

class VideoSettingsView extends ConsumerWidget {
  const VideoSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('PLAYBACK'),
        _settingsCard([
          _switchRow(context, ref, 'Resume Where Left Off', 'Continue from last position', Icons.play_circle_outline, resumePlaybackProvider),
          _divider(),
          _switchRow(context, ref, 'Auto-play Next Video', 'Play next file in folder when done', Icons.skip_next, autoPlayNextProvider),
          _divider(),
          _switchRow(context, ref, 'Loop Video', 'Repeat video indefinitely', Icons.loop, loopVideoProvider),
        ]),
        const SizedBox(height: 24),

        _sectionHeader('CONTROLS'),
        _settingsCard([
          _switchRow(context, ref, 'Swipe Gestures', 'Swipe to adjust volume/brightness', Icons.swipe, swipeGesturesProvider),
        ]),
        const SizedBox(height: 24),

        _sectionHeader('APPEARANCE'),
        _settingsCard([
          _switchRow(context, ref, 'Dark Mode', 'Use dark background in player', Icons.dark_mode, darkModeProvider),
        ]),
        const SizedBox(height: 24),

        _sectionHeader('ABOUT'),
        _settingsCard([
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Argus Archive', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Version 1.1.0', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Native ExoPlayer • FTS4 Search • Multi-format Archives', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(left: 8, bottom: 8),
    child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ArgusColors.primary, letterSpacing: 1.2)),
  );

  Widget _settingsCard(List<Widget> rows) => Container(
    decoration: BoxDecoration(
      color: ArgusColors.surfaceDark.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
    ),
    child: Column(children: rows),
  );

  Widget _divider() => const Divider(height: 1, thickness: 1, color: Colors.white10, indent: 56);

  Widget _switchRow(BuildContext context, WidgetRef ref, String title, String subtitle, IconData icon, StateProvider<bool> provider) {
    final value = ref.watch(provider);
    return ListTile(
      leading: Icon(icon, color: ArgusColors.primary, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: Switch(
        value: value,
        activeColor: ArgusColors.primary,
        onChanged: (_) => ref.read(provider.notifier).state = !value,
      ),
    );
  }
}
