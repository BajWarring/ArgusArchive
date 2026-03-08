import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VideoHistoryItem {
  final String path;
  final String title;
  final int positionMs;
  final int durationMs;
  final double audioDelayMs;
  final double subtitleDelayMs;
  final DateTime lastPlayed;

  VideoHistoryItem({
    required this.path,
    required this.title,
    required this.positionMs,
    required this.durationMs,
    this.audioDelayMs = 0.0,
    this.subtitleDelayMs = 0.0,
    required this.lastPlayed,
  });

  Map<String, dynamic> toMap() => {
    'path': path,
    'title': title,
    'positionMs': positionMs,
    'durationMs': durationMs,
    'audioDelayMs': audioDelayMs,
    'subtitleDelayMs': subtitleDelayMs,
    'lastPlayed': lastPlayed.toIso8601String(),
  };

  factory VideoHistoryItem.fromMap(Map<String, dynamic> map) => VideoHistoryItem(
    path: map['path'],
    title: map['title'],
    positionMs: map['positionMs'] ?? 0,
    durationMs: map['durationMs'] ?? 0,
    audioDelayMs: (map['audioDelayMs'] ?? 0.0).toDouble(),
    subtitleDelayMs: (map['subtitleDelayMs'] ?? 0.0).toDouble(),
    lastPlayed: DateTime.parse(map['lastPlayed']),
  );
}

class VideoHistoryNotifier extends StateNotifier<List<VideoHistoryItem>> {
  VideoHistoryNotifier() : super([]) { _load(); }
  File? _file;

  Future<void> _load() async {
    final docDir = await getApplicationDocumentsDirectory();
    _file = File(p.join(docDir.path, 'video_history.json'));
    if (await _file!.exists()) {
      try {
        final json = jsonDecode(await _file!.readAsString()) as List;
        state = json.map((e) => VideoHistoryItem.fromMap(e)).toList();
      } catch (_) {}
    }
  }
  
  Future<void> save(VideoHistoryItem item) async {
    final List<VideoHistoryItem> updated = List.from(state);
    updated.removeWhere((e) => e.path == item.path);
    updated.insert(0, item);
    if (updated.length > 50) updated.removeLast(); // Keep last 50
    state = updated;
    if (_file != null) {
      await _file!.writeAsString(jsonEncode(updated.map((e) => e.toMap()).toList()));
    }
  }
}

final videoHistoryProvider = StateNotifierProvider<VideoHistoryNotifier, List<VideoHistoryItem>>((ref) => VideoHistoryNotifier());
