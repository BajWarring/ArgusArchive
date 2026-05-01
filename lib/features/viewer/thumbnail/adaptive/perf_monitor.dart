
import 'dart:io';
import 'package:flutter/scheduler.dart';
import '../isolate/isolate_pool.dart';
import '../services/thumbnail_queue.dart';
import 'perf_state.dart';

class PerfMonitor {
  static final _frameTimes = <double>[];
  static const _window = 30;

  static void start() {
    SchedulerBinding.instance.addTimingsCallback((timings) {
      for (final t in timings) {
        final ms = t.totalSpan.inMicroseconds / 1000.0;
        _frameTimes.add(ms);
        if (_frameTimes.length > _window) _frameTimes.removeAt(0);
      }
    });
  }

  static PerfState snapshot() {
    final avg = _frameTimes.isEmpty
        ? 16.0
        : _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;
    return PerfState(
      avgFrameMs: avg,
      queueLength: ThumbnailQueue.length,
      activeWorkers: IsolatePool.activeTasks,
      cpuCores: Platform.numberOfProcessors,
    );
  }
}
