import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'operation_popup_card.dart';

class StandaloneOperationPopup extends StatefulWidget {
  final String title;
  final String destination;
  final Future<void> Function(void Function(double progress, String currentFile)) action;
  final VoidCallback onComplete;

  const StandaloneOperationPopup({
    super.key,
    required this.title,
    required this.destination,
    required this.action,
    required this.onComplete,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String destination,
    required Future<void> Function(void Function(double progress, String currentFile)) action,
    required VoidCallback onComplete,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black45,
      barrierDismissible: false,
      builder: (context) => Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Material(
            color: Colors.transparent,
            child: StandaloneOperationPopup(
              title: title, destination: destination, action: action, onComplete: onComplete,
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<StandaloneOperationPopup> createState() => _StandaloneOperationPopupState();
}

class _StandaloneOperationPopupState extends State<StandaloneOperationPopup> {
  double _progress = 0.0;
  String _currentFile = 'Starting...';
  bool _isCanceled = false;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _runAction();
  }

  Future<void> _runAction() async {
    await widget.action((progress, currentFile) {
      if (mounted && !_isCanceled) {
        setState(() {
          _progress = progress;
          _currentFile = currentFile;
        });
      }
    });

    if (mounted && !_isCanceled) {
      setState(() {
        _isComplete = true;
        _progress = 1.0;
      });
      widget.onComplete();
      
      // FIXED: Capture the navigator before the async delay
      final nav = Navigator.of(context);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          nav.pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return OperationPopupCard(
      title: _isCanceled ? "Canceled" : widget.title,
      destination: "To: ${p.basename(widget.destination)}",
      currentFile: _currentFile,
      progress: _progress,
      currentItems: (_progress * 100).toInt(),
      totalItems: 100,
      speedText: "${(_progress * 100).toStringAsFixed(1)}%",
      isAnimating: !_isComplete && !_isCanceled,
      isCanceled: _isCanceled,
      onHide: () => Navigator.of(context).pop(),
      onCancel: () {
        setState(() => _isCanceled = true);
        
        // FIXED: Capture the navigator before the async delay
        final nav = Navigator.of(context);
        Future.delayed(const Duration(seconds: 1), () { 
          if (mounted) {
            nav.pop(); 
          }
        });
      },
    );
  }
}
