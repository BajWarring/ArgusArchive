import 'package:flutter/material.dart';
import '../../../core/services/logger_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showHiddenFiles = false;
  bool _debugLogs = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Show hidden files'),
            value: _showHiddenFiles,
            onChanged: (v) => setState(() => _showHiddenFiles = v),
          ),
          SwitchListTile(
            title: const Text('Debug logging'),
            value: _debugLogs,
            onChanged: (v) {
              setState(() => _debugLogs = v);
              LoggerService.debugEnabled = v;
            },
          ),
        ],
      ),
    );
  }
}
