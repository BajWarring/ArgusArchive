import 'package:flutter/material.dart';
import '../../ui_theme.dart';

class OperationBar extends StatelessWidget {
  final String operationTitle; // e.g. "Copying" or "Cutting"
  final String itemName;
  final IconData icon;
  final VoidCallback onCancel;
  final VoidCallback onPaste;

  const OperationBar({
    super.key, required this.operationTitle, required this.itemName, 
    required this.icon, required this.onCancel, required this.onPaste
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Invert the theme to match HTML: Dark mode gets light bar, Light mode gets dark bar
    final bgColor = isDark ? Colors.white : Colors.black;
    final textColor = isDark ? Colors.black87 : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: isDark ? Colors.black12 : Colors.white24, shape: BoxShape.circle),
                  child: Icon(icon, color: textColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(operationTitle.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: textColor.withValues(alpha: 0.8))),
                      Text(itemName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(foregroundColor: textColor.withValues(alpha: 0.8), textStyle: const TextStyle(fontWeight: FontWeight.bold)),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: onPaste,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ArgusColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  shadowColor: ArgusColors.primary.withValues(alpha: 0.5),
                ),
                child: const Text('Paste Here', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          )
        ],
      ),
    );
  }
}
