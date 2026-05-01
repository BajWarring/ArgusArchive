/// Lightweight cooperative cancellation token.
/// Passed to long-running tasks; they check [isCancelled] at safe points.
class CancelToken {
  bool _isCancelled = false;

  void cancel() => _isCancelled = true;

  bool get isCancelled => _isCancelled;
}
