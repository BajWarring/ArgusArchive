import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ui_theme.dart';
import '../../../providers/ui_mode_provider.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('DEVELOPER OPTIONS'),
        _buildSettingsCard([
          _buildSettingsRow('Use Legacy Debug UI', trailing: Switch(
            value: ref.watch(useDebugUiProvider),
            activeColor: ArgusColors.primary,
            onChanged: (val) {
              ref.read(useDebugUiProvider.notifier).state = val;
            },
          )),
        ]),
        const SizedBox(height: 24),
        _buildSectionHeader('APPEARANCE'),
        _buildSettingsCard([
          _buildSettingsRow('Dark Mode', trailing: Switch(
            value: Theme.of(context).brightness == Brightness.dark,
            activeColor: ArgusColors.primary,
            onChanged: (val) {},
          )),
        ]),
        const SizedBox(height: 24),
        _buildSectionHeader('ABOUT'),
        _buildSettingsCard([
          _buildSettingsRow('Version', trailing: const Text('1.0.0 (Beta)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey))),
        ]),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ArgusColors.primary, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: ArgusColors.surfaceDark.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(children: rows),
    );
  }

  Widget _buildSettingsRow(String title, {required Widget trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          trailing,
        ],
      ),
    );
  }
}
