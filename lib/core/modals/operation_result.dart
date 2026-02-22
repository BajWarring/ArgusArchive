/// Standardized error codes for adapter and service operations.
enum ErrorCode { 
  none, 
  network, 
  permissionDenied, 
  notFound, 
  ioError, 
  unsupportedFormat 
}

/// A standard wrapper for success/failure results + error codes.
/// This prevents us from relying on raw exception throwing across architectural boundaries.
class OperationResult<T> {
  final T? data;
  final bool isSuccess;
  final String? errorMessage;
  final ErrorCode errorCode;

  const OperationResult.success(this.data)
      : isSuccess = true,
        errorMessage = null,
        errorCode = ErrorCode.none;

  const OperationResult.failure(this.errorMessage, {this.errorCode = ErrorCode.ioError})
      : isSuccess = false,
        data = null;
}
