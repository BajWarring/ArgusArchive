import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MediaHistoryItem {
  final String path;
  final String title;
  final String type; // 'video' or 'audio'
  final int positionMs;
  final int durationMs;
  final double audioDelayMs;
  final double subtitleDelayMs;
  final DateTime lastPlayed;

  MediaHistoryItem({
    required this.path, required this.title, required this.type,
    required this.positionMs, required this.durationMs,
    this.audioDelayMs = 0.0, this.subtitleDelayMs = 0.0, required this.lastPlayed,
  });

  Map<String, dynamic> toMap() => {
    'path': path, 'title': title, 'type': type,
    'positionMs': positionMs, 'durationMs': durationMs,
    'audioDelayMs': audioDelayMs, 'subtitleDelayMs': subtitleDelayMs,
    'lastPlayed': lastPlayed.toIso8601String(),
  };

  factory MediaHistoryItem.fromMap(Map<String, dynamic> map) => MediaHistoryItem(
    path: map['path'], title: map['title'], type: map['type'] ?? 'video',
    positionMs: map['positionMs'] ?? 0, durationMs: map['durationMs'] ?? 0,
    audioDelayMs: (map['audioDelayMs'] ?? 0.0).toDouble(),
    subtitleDelayMs: (map['subtitleDelayMs'] ?? 0.0).toDouble(),
    lastPlayed: DateTime.parse(map['lastPlayed']),
  );
}

class MediaHistoryNotifier extends StateNotifier<List<MediaHistoryItem>> {
  MediaHistoryNotifier() : super([]) { _load(); }
  File? _file;

  Future<void> _load() async {
    final docDir = await getApplicationDocumentsDirectory();
    _file = File(p.join(docDir.path, 'media_history.json'));
    if (await _file!.exists()) {
      try {
        final json = jsonDecode(await _file!.readAsString()) as List;
        state = json.map((e) => MediaHistoryItem.fromMap(e)).toList();
      } catch (_) {}
    }
  }
  
  Future<void> save(MediaHistoryItem item) async {
    final List<MediaHistoryItem> updated = List.from(state);
    updated.removeWhere((e) => e.path == item.path);
    updated.insert(0, item);
    if (updated.length > 50) updated.removeLast();
    state = updated;
    if (_file != null) await _file!.writeAsString(jsonEncode(updated.map((e) => e.toMap()).toList()));
  }
}

final mediaHistoryProvider = StateNotifierProvider<MediaHistoryNotifier, List<MediaHistoryItem>>((ref) => MediaHistoryNotifier());
