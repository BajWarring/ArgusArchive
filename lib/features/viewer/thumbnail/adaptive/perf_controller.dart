import 'dart:async';
import '../isolate/isolate_pool.dart';
import '../services/thumbnail_queue.dart';
import '../services/thumbnail_visibility.dart';
import '../services/thumbnail_generator.dart';
import 'perf_monitor.dart';
import 'perf_policy.dart';

class PerfController {
  static Timer? _loop;

  static void start() {
    PerfMonitor.start();
    _loop = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      final s = PerfMonitor.snapshot();
      _decideAndApply(s);
    });
  }

  static void _decideAndApply(s) {
    final minP = PerfPolicy.minPool(s.cpuCores);
    final maxP = PerfPolicy.maxPool(s.cpuCores);

    int targetPool = IsolatePool.size;
    if (s.avgFrameMs > PerfPolicy.jankMs) {
      targetPool = (targetPool - 1).clamp(minP, maxP);
    } else if (s.queueLength > 20 && s.avgFrameMs < PerfPolicy.smoothMs) {
      targetPool = (targetPool + 1).clamp(minP, maxP);
    }

    int targetConcurrent = ThumbnailQueue.maxConcurrent;
    if (s.avgFrameMs > PerfPolicy.jankMs) {
      targetConcurrent = (targetConcurrent - 1)
          .clamp(PerfPolicy.minConcurrent, PerfPolicy.maxConcurrent);
    } else if (s.queueLength > 20 && s.avgFrameMs < PerfPolicy.smoothMs) {
      targetConcurrent = (targetConcurrent + 1)
          .clamp(PerfPolicy.minConcurrent, PerfPolicy.maxConcurrent);
    }

    int quality = ThumbnailGenerator.quality;
    if (s.avgFrameMs > PerfPolicy.jankMs) {
      quality = PerfPolicy.lowQuality;
    } else if (s.avgFrameMs < PerfPolicy.smoothMs && s.queueLength < 10) {
      quality = PerfPolicy.highQuality;
    }

    int prefetch = ThumbnailVisibility.prefetchRange;
    if (s.avgFrameMs > PerfPolicy.jankMs) {
      prefetch = PerfPolicy.prefetchNear;
    } else {
      prefetch = PerfPolicy.prefetchFar;
    }

    if (IsolatePool.size != targetPool) IsolatePool.resize(targetPool);
    if (ThumbnailQueue.maxConcurrent != targetConcurrent) {
      ThumbnailQueue.setConcurrency(targetConcurrent);
    }
    if (ThumbnailGenerator.quality != quality) {
      ThumbnailGenerator.setQuality(quality);
    }
    if (ThumbnailVisibility.prefetchRange != prefetch) {
      ThumbnailVisibility.prefetchRange = prefetch;
    }
  }

  static void dispose() => _loop?.cancel();
}
