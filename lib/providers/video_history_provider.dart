import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VideoHistoryItem {
  final String path;
  final String title;
  final int positionMs;
  final int durationMs;
  final String? audioTrackId;
  final String? subtitleTrackId;
  final int audioDelayMs;
  final int subtitleDelayMs;
  final DateTime lastPlayed;

  VideoHistoryItem({
    required this.path,
    required this.title,
    required this.positionMs,
    required this.durationMs,
    this.audioTrackId,
    this.subtitleTrackId,
    this.audioDelayMs = 0,
    this.subtitleDelayMs = 0,
    required this.lastPlayed,
  });

  Map<String, dynamic> toMap() => {
    'path': path,
    'title': title,
    'positionMs': positionMs,
    'durationMs': durationMs,
    'audioTrackId': audioTrackId,
    'subtitleTrackId': subtitleTrackId,
    'audioDelayMs': audioDelayMs,
    'subtitleDelayMs': subtitleDelayMs,
    'lastPlayed': lastPlayed.toIso8601String(),
  };

  factory VideoHistoryItem.fromMap(Map<String, dynamic> map) => VideoHistoryItem(
    path: map['path'],
    title: map['title'],
    positionMs: map['positionMs'] ?? 0,
    durationMs: map['durationMs'] ?? 0,
    audioTrackId: map['audioTrackId'],
    subtitleTrackId: map['subtitleTrackId'],
    audioDelayMs: map['audioDelayMs'] ?? 0,
    subtitleDelayMs: map['subtitleDelayMs'] ?? 0,
    lastPlayed: DateTime.parse(map['lastPlayed']),
  );
}

class VideoHistoryNotifier extends StateNotifier<List<VideoHistoryItem>> {
  VideoHistoryNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('video_history') ?? [];
    state = data.map((e) => VideoHistoryItem.fromMap(jsonDecode(e))).toList();
  }

  Future<void> save(VideoHistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final List<VideoHistoryItem> updated = List.from(state);
    
    // Remove if exists to move to top
    updated.removeWhere((e) => e.path == item.path);
    updated.insert(0, item);
    
    // Keep last 50
    if (updated.length > 50) updated.removeLast();
    
    state = updated;
    await prefs.setStringList('video_history', updated.map((e) => jsonEncode(e.toMap())).toList());
  }
}

final videoHistoryProvider = StateNotifierProvider<VideoHistoryNotifier, List<VideoHistoryItem>>((ref) {
  return VideoHistoryNotifier();
});
