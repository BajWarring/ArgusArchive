import 'package:flutter/material.dart';
import '../animations/voyager_progress.dart'; // Imports the separated animations

class OperationPopupCard extends StatelessWidget {
  final String title;
  final String destination;
  final String currentFile;
  final double progress;
  final int currentItems;
  final int totalItems;
  final String speedText;
  final bool isAnimating;
  final bool isCanceled;
  final bool isFailed;
  final String? errorMessage;
  final VoidCallback onHide;
  final VoidCallback onCancel;

  const OperationPopupCard({
    super.key,
    required this.title,
    required this.destination,
    required this.currentFile,
    required this.progress,
    required this.currentItems,
    required this.totalItems,
    required this.speedText,
    required this.isAnimating,
    required this.isCanceled,
    this.isFailed = false,
    this.errorMessage,
    required this.onHide,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isFailed ? const Color(0xFFE11D48) : (isCanceled ? const Color(0xFFE11D48) : const Color(0xFF1E293B));
    final barColor = isFailed || isCanceled ? const Color(0xFFE11D48) : const Color(0xFF06B6D4);

    return Container(
      width: 384,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor)),
                  const SizedBox(width: 8),
                  if (isAnimating && !isCanceled && !isFailed) const PulsingDots(),
                ],
              ),
              Row(
                children: [
                  Text(speedText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text("•", style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12))),
                  Text("$currentItems / $totalItems Items", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                ],
              )
            ],
          ),
          
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC).withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFF1F5F9))),
            padding: const EdgeInsets.all(8),
            child: AspectRatio(
              aspectRatio: 800 / 210, 
              child: isFailed || isCanceled 
                  ? CustomPaint(painter: StaticBarPainter(progress: progress, color: barColor)) 
                  : VoyagerProgress(progress: progress, isAnimating: isAnimating),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(destination, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (isAnimating && !isCanceled && !isFailed)
                          const Padding(padding: EdgeInsets.only(right: 6), child: SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF06B6D4)))),
                        Expanded(child: Text(isFailed ? (errorMessage ?? 'Operation failed') : currentFile, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: isFailed ? const Color(0xFFE11D48) : const Color(0xFF94A3B8)))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: onHide,
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), minimumSize: Size.zero, foregroundColor: const Color(0xFF64748B), side: const BorderSide(color: Color(0xFFE2E8F0)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                    child: Text(isCanceled || isFailed || progress >= 1.0 ? "Close" : "Hide", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  if (!isCanceled && !isFailed && progress < 1.0) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: onCancel,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), minimumSize: Size.zero, backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                      child: const Text("Cancel", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ]
                ],
              )
            ],
          )
        ],
      ),
    );
  }
}
