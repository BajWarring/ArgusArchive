/// Snapshot of system performance at a point in time.
class PerfState {
  final double avgFrameMs; // UI smoothness — 16ms ideal at 60fps
  final int queueLength;   // pending thumbnail tasks
  final int activeWorkers; // isolates currently busy
  final int cpuCores;

  const PerfState({
    required this.avgFrameMs,
    required this.queueLength,
    required this.activeWorkers,
    required this.cpuCores,
  });
}
