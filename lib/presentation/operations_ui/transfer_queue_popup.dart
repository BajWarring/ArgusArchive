import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../services/transfer/transfer_task.dart';
import '../../services/notifications/notification_service.dart';
import '../debug_ui/providers.dart';
import 'operation_popup_card.dart';

class TransferQueuePopup extends ConsumerStatefulWidget {
  final List<String> taskIds;
  final String operationId;

  const TransferQueuePopup({super.key, required this.taskIds, required this.operationId});

  static Future<void> show(BuildContext context, List<String> taskIds) {
    return showDialog(
      context: context,
      barrierColor: Colors.black45,
      barrierDismissible: false,
      builder: (context) => Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Material(color: Colors.transparent, child: TransferQueuePopup(taskIds: taskIds, operationId: DateTime.now().millisecondsSinceEpoch.toString())),
        ),
      ),
    );
  }

  @override
  ConsumerState<TransferQueuePopup> createState() => _TransferQueuePopupState();
}

class _TransferQueuePopupState extends ConsumerState<TransferQueuePopup> with WidgetsBindingObserver {
  bool _isHidden = false;
  bool _isBackground = false;
  bool _isComplete = false;
  StreamSubscription? _notifSub;

  int get _notifId => widget.operationId.hashCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notifSub = NotificationService.actionStream.stream.listen((payload) {
      if (payload == widget.operationId) _handleCancelAll();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isBackground = (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden);
    if (!_isBackground && _isHidden && !_isComplete) {
      NotificationService.cancelNotification(_notifId);
    }
  }

  void _updateNotification(double progress, String file, String title, bool isCanceled, bool isFailed) {
    if ((_isHidden || _isBackground) && !_isComplete && !isCanceled && !isFailed) {
      NotificationService.showProgressNotification(
        id: _notifId,
        title: title,
        body: file,
        progress: (progress * 100).toInt(),
        payload: widget.operationId,
      );
    }
  }

  void _handleCancelAll() {
    final queue = ref.read(transferQueueProvider);
    for (var id in widget.taskIds) {
      queue.cancel(id);
    }
    NotificationService.cancelNotification(_notifId);
    NotificationService.showCompletionNotification(id: _notifId, title: 'Transfer Canceled', body: 'Operation aborted by user');
    if (!_isHidden && mounted) {
      Navigator.of(context).pop();
    }
  }

  String _getOperationName(TransferOperation operation) {
    switch (operation) {
      case TransferOperation.copy: return 'Copying';
      case TransferOperation.move: return 'Moving';
      case TransferOperation.extract: return 'Extracting';
      case TransferOperation.compress: return 'Compressing';
      case TransferOperation.delete: return 'Deleting';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(queueTasksStreamProvider);

    return tasksAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
      data: (allTasks) {
        final myTasks = allTasks.where((t) => widget.taskIds.contains(t.id)).toList();
        if (myTasks.isEmpty) return const SizedBox.shrink();

        _isComplete = myTasks.every((t) => t.status == TransferStatus.completed || t.status == TransferStatus.cancelled || t.status == TransferStatus.failed);
        
        if (_isComplete) {
          NotificationService.cancelNotification(_notifId);
          final hasErrors = myTasks.any((t) => t.status == TransferStatus.failed);
          if (!myTasks.every((t) => t.status == TransferStatus.cancelled)) {
            NotificationService.showCompletionNotification(
              id: _notifId, 
              title: hasErrors ? 'Transfer Finished with Errors' : 'Transfer Complete', 
              body: hasErrors ? 'Some files failed to transfer.' : 'All files processed successfully.'
            );
          }
          
          if (!_isHidden) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pop();
                ref.invalidate(directoryContentsProvider);
              }
            });
          }
        }

        final activeTask = myTasks.firstWhere(
          (t) => t.status == TransferStatus.inProgress,
          orElse: () => myTasks.firstWhere((t) => t.status == TransferStatus.pending, orElse: () => myTasks.last)
        );

        final totalBytes = myTasks.fold<int>(0, (sum, t) => sum + t.totalBytes);
        final transferredBytes = myTasks.fold<int>(0, (sum, t) => sum + t.transferredBytes);
        final overallProgress = totalBytes == 0 ? 0.0 : transferredBytes / totalBytes;
        
        final completedItems = myTasks.where((t) => t.status == TransferStatus.completed).length;
        final mbTransferred = (transferredBytes / (1024 * 1024)).toStringAsFixed(1);
        final mbTotal = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
        
        bool isCanceled = myTasks.every((t) => t.status == TransferStatus.cancelled);
        bool isFailed = activeTask.status == TransferStatus.failed;
        String opName = _getOperationName(activeTask.operation);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateNotification(overallProgress, p.basename(activeTask.sourcePath), opName, isCanceled, isFailed);
        });

        return OperationPopupCard(
          title: isCanceled ? "Canceled" : (isFailed ? "Failed" : opName),
          destination: "To: ${p.dirname(activeTask.destPath)}",
          currentFile: p.basename(activeTask.sourcePath),
          progress: overallProgress,
          currentItems: completedItems,
          totalItems: myTasks.length,
          speedText: "$mbTransferred / $mbTotal MB",
          isAnimating: !_isComplete && !isCanceled && !isFailed,
          isCanceled: isCanceled,
          isFailed: isFailed,
          onHide: () {
            setState(() => _isHidden = true);
            _updateNotification(overallProgress, p.basename(activeTask.sourcePath), opName, isCanceled, isFailed);
            Navigator.of(context).pop();
          },
          onCancel: _handleCancelAll,
        );
      }
    );
  }
}
