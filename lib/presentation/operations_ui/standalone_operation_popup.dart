import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../services/notifications/notification_service.dart';
import 'operation_popup_card.dart';

class StandaloneOperationPopup extends StatefulWidget {
  final String title;
  final String destination;
  final Future<bool> Function(Function(double, String) onProgress, ValueNotifier<bool> cancelToken) action;
  final VoidCallback onComplete;
  final String operationId;

  const StandaloneOperationPopup({
    super.key, required this.title, required this.destination, required this.action, required this.onComplete, required this.operationId,
  });

  static Future<void> show({
    required BuildContext context, required String title, required String destination,
    required Future<bool> Function(Function(double, String) onProgress, ValueNotifier<bool> cancelToken) action,
    required VoidCallback onComplete,
  }) {
    return showDialog(
      context: context, barrierColor: Colors.black45, barrierDismissible: false,
      builder: (context) => Align(
        alignment: Alignment.bottomRight,
        child: Padding(padding: const EdgeInsets.all(24.0), child: Material(color: Colors.transparent, child: StandaloneOperationPopup(
          title: title, destination: destination, action: action, onComplete: onComplete, operationId: DateTime.now().millisecondsSinceEpoch.toString(),
        ))),
      ),
    );
  }

  @override
  State<StandaloneOperationPopup> createState() => _StandaloneOperationPopupState();
}

class _StandaloneOperationPopupState extends State<StandaloneOperationPopup> with WidgetsBindingObserver {
  double _progress = 0.0;
  String _currentFile = 'Starting...';
  bool _isCanceled = false;
  bool _isComplete = false;
  bool _isFailed = false;
  bool _isHidden = false;
  bool _isBackground = false;
  
  final ValueNotifier<bool> _cancelToken = ValueNotifier<bool>(false);
  StreamSubscription? _notifSub;

  int get _notifId => widget.operationId.hashCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // FIXED: Listen to the .stream of the StreamController
    _notifSub = NotificationService.actionStream.stream.listen((payload) {
      if (payload == widget.operationId) _handleCancel();
    });

    _runAction();
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
    if (!_isBackground && _isHidden && !_isComplete && !_isCanceled) {
      NotificationService.cancelNotification(_notifId);
    }
  }

  void _updateNotification() {
    if ((_isHidden || _isBackground) && !_isComplete && !_isCanceled && !_isFailed) {
      NotificationService.showProgressNotification(
        id: _notifId,
        title: widget.title,
        body: _currentFile,
        progress: (_progress * 100).toInt(),
        payload: widget.operationId,
      );
    }
  }

  Future<void> _runAction() async {
    final success = await widget.action((progress, currentFile) {
      if (mounted && !_isCanceled) {
        setState(() { _progress = progress; _currentFile = currentFile; });
        _updateNotification();
      }
    }, _cancelToken);

    if (mounted && !_isCanceled) {
      setState(() {
        _isComplete = success;
        _isFailed = !success;
        if (success) _progress = 1.0;
      });
      
      NotificationService.cancelNotification(_notifId);
      NotificationService.showCompletionNotification(
        id: _notifId,
        title: success ? '${widget.title} Complete' : '${widget.title} Failed',
        body: success ? 'Files processed successfully' : 'Operation encountered an error',
      );

      if (success) {
        widget.onComplete();
        if (!_isHidden) {
          final nav = Navigator.of(context);
          Future.delayed(const Duration(milliseconds: 500), () { if (mounted) nav.pop(); });
        }
      }
    }
  }

  void _handleCancel() {
    _cancelToken.value = true;
    NotificationService.cancelNotification(_notifId);
    NotificationService.showCompletionNotification(id: _notifId, title: '${widget.title} Canceled', body: 'Operation aborted by user');
    if (mounted) {
      setState(() { _isCanceled = true; _isFailed = false; });
      if (!_isHidden) {
        final nav = Navigator.of(context);
        Future.delayed(const Duration(seconds: 1), () { if (mounted) nav.pop(); });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OperationPopupCard(
      title: _isCanceled ? "Canceled" : (_isFailed ? "Failed" : widget.title),
      destination: "To: ${p.basename(widget.destination)}",
      currentFile: _currentFile,
      progress: _progress,
      currentItems: (_progress * 100).toInt(),
      totalItems: 100,
      speedText: "${(_progress * 100).toStringAsFixed(1)}%",
      isAnimating: !_isComplete && !_isCanceled && !_isFailed,
      isCanceled: _isCanceled,
      isFailed: _isFailed,
      onHide: () {
        setState(() => _isHidden = true);
        _updateNotification();
        Navigator.of(context).pop(); 
      },
      onCancel: _handleCancel,
    );
  }
}
