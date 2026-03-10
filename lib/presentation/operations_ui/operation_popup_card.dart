import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
    required this.onHide,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
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
          // Row 1: Header (Title & Metrics)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isCanceled ? const Color(0xFFE11D48) : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isAnimating && !isCanceled) const PulsingDots(),
                ],
              ),
              Row(
                children: [
                  Text(speedText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text("•", style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                  ),
                  Text("$currentItems / $totalItems Items", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                ],
              )
            ],
          ),
          
          const SizedBox(height: 12),

          // Row 2: Voyager Progress Bar 
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            padding: const EdgeInsets.all(8),
            child: AspectRatio(
              aspectRatio: 800 / 210, // Exact SVG viewBox ratio
              child: VoyagerProgress(progress: progress, isAnimating: isAnimating),
            ),
          ),

          const SizedBox(height: 12),

          // Row 3: Active Details & Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (isAnimating && !isCanceled)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: SizedBox(
                              width: 10, height: 10,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF06B6D4)),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            currentFile,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
                          ),
                        ),
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
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text("Hide", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: onCancel,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text("Cancel", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              )
            ],
          )
        ],
      ),
    );
  }
}

// --- ANIMATED CSS-STYLE STATUS DOTS ---
class PulsingDots extends StatefulWidget {
  const PulsingDots({super.key});
  @override
  State<PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<PulsingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (index) {
        return FadeTransition(
          opacity: Tween<double>(begin: 0.2, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Interval((index * 0.2), 1.0, curve: Curves.easeInOut))),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.5), width: 6, height: 6,
            decoration: const BoxDecoration(color: Color(0xFF22D3EE), shape: BoxShape.circle),
          ),
        );
      }),
    );
  }
}

// --- VOYAGER PROGRESS WRAPPER ---
class VoyagerProgress extends StatefulWidget {
  final double progress;
  final bool isAnimating;
  const VoyagerProgress({super.key, required this.progress, required this.isAnimating});
  @override
  State<VoyagerProgress> createState() => _VoyagerProgressState();
}

class _VoyagerProgressState extends State<VoyagerProgress> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _waveOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (widget.isAnimating) _ticker.start();
  }

  @override
  void didUpdateWidget(VoyagerProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !_ticker.isTicking) {
      _ticker.start();
    } else if (!widget.isAnimating && _ticker.isTicking) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    setState(() => _waveOffset = (elapsed.inMilliseconds / 1000.0 * 90.0) % 160.0);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: VoyagerPainter(progress: widget.progress, waveOffset: _waveOffset));
  }
}

// --- VOYAGER SVG PHYSICS PAINTER ---
class VoyagerPainter extends CustomPainter {
  final double progress;
  final double waveOffset;
  VoyagerPainter({required this.progress, required this.waveOffset});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 800.0, size.height / 210.0);
    
    const double waveLength = 160.0;
    const double amplitude = 14.0;
    const double startX = 0.0;
    const double endX = 700.0;
    const double waveStartX = 50.0;
    const double waveEndX = 750.0;

    double getWaveY(double x, double offset) => 100.0 - sin(((x + offset) / waveLength) * pi * 2) * amplitude;
    double currentX = startX + ((endX - startX) * progress);

    Paint bgPaint = Paint()..color = const Color(0xFFE2E8F0)..style = PaintingStyle.stroke..strokeWidth = 6.0..strokeCap = StrokeCap.round;
    Path bgPath = Path()..moveTo(waveStartX, getWaveY(waveStartX, waveOffset));
    for (double x = waveStartX + 5; x <= waveEndX; x += 5) bgPath.lineTo(x, getWaveY(x, waveOffset));
    bgPath.lineTo(waveEndX, getWaveY(waveEndX, waveOffset));
    canvas.drawPath(bgPath, bgPaint);

    Paint fgPaint = Paint()..color = const Color(0xFF06B6D4)..style = PaintingStyle.stroke..strokeWidth = 6.0..strokeCap = StrokeCap.round;
    double fgEndX = currentX + 50.0;
    Path fgPath = Path();
    if (fgEndX > waveStartX) {
      fgPath.moveTo(waveStartX, getWaveY(waveStartX, waveOffset));
      for (double x = waveStartX + 5; x < fgEndX; x += 5) fgPath.lineTo(x, getWaveY(x, waveOffset));
      fgPath.lineTo(fgEndX, getWaveY(fgEndX, waveOffset));
      canvas.drawPath(fgPath, fgPaint);
    }

    double boatGlobalCenterX = currentX + 50.0;
    double boatY = getWaveY(boatGlobalCenterX, waveOffset) - 100.0;
    double dyDx = -cos(((boatGlobalCenterX + waveOffset) / waveLength) * pi * 2) * amplitude * ((pi * 2) / waveLength);
    double angle = atan(dyDx) * 0.85;

    canvas.save();
    canvas.translate(currentX, 15.0 + boatY);
    canvas.save();
    canvas.translate(50.0, 85.0);
    canvas.rotate(angle);
    canvas.translate(-50.0, -85.0);
    
    _drawPolygon(canvas, [const Offset(50, 70), const Offset(50, 15), const Offset(85, 70)], const Color(0xFF06B6D4));
    _drawPolygon(canvas, [const Offset(50, 70), const Offset(50, 25), const Offset(15, 70)], const Color(0xFF22D3EE));
    _drawPolygon(canvas, [const Offset(5, 70), const Offset(95, 70), const Offset(75, 90), const Offset(25, 90)], const Color(0xFF0891B2));
    _drawPolygon(canvas, [const Offset(5, 70), const Offset(50, 70), const Offset(25, 90)], const Color(0xFF164E63).withValues(alpha: 0.3));
    
    canvas.restore();
    
    int percentValue = (progress * 100).floor();
    TextSpan span = TextSpan(style: const TextStyle(fontSize: 38.0, fontWeight: FontWeight.w800, color: Color(0xFF06B6D4)), text: '$percentValue%');
    TextPainter tp = TextPainter(text: span, textAlign: TextAlign.center, textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(50.0 - (tp.width / 2), 175.0 - (tp.height / 2)));
    
    canvas.restore();
    canvas.restore();
  }

  void _drawPolygon(Canvas canvas, List<Offset> points, Color color) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) path.lineTo(points[i].dx, points[i].dy);
    path.close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant VoyagerPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.waveOffset != waveOffset;
}
