class ThumbnailVisibility {
  static int firstVisible = 0;
  static int lastVisible = 0;

  /// Adjusted by PerfController (prefetchNear or prefetchFar)
  static int prefetchRange = 10;

  static bool isVisible(int index) {
    return index >= firstVisible && index <= lastVisible;
  }

  static bool isNearVisible(int index) {
    return index >= (firstVisible - prefetchRange) &&
        index <= (lastVisible + prefetchRange);
  }

  /// Returns priority for a given item index.
  /// 1000 = currently visible, 500 = prefetch zone, 0 = ignore
  static int getPriority(int index) {
    if (isVisible(index)) return 1000;
    if (isNearVisible(index)) return 500;
    return 0;
  }
}
