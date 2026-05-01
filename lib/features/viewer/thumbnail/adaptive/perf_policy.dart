/// Static policy constants used by PerfController.
/// Tweak these to tune behavior for your target devices.
class PerfPolicy {
  // Frame thresholds (ms)
  static const double smoothMs = 18.0;
  static const double jankMs   = 24.0;

  // Isolate pool bounds
  static int minPool(int cores) => 1;
  static int maxPool(int cores) => (cores / 2).ceil().clamp(1, 4);

  // Queue concurrency bounds
  static const int minConcurrent = 1;
  static const int maxConcurrent = 4;

  // Thumbnail quality (0–100)
  static const int highQuality = 80;
  static const int lowQuality  = 55;

  // Prefetch window (items beyond viewport)
  static const int prefetchNear = 6;
  static const int prefetchFar  = 12;
}
