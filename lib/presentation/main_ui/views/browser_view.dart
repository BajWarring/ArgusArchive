import 'package:flutter/material.dart';
import '../../ui_theme.dart';

class BrowserView extends StatelessWidget {
  const BrowserView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      itemBuilder: (context, index) {
        bool isFolder = index < 3;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ArgusColors.surfaceDark.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isFolder ? ArgusColors.primary.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.2),
                child: Icon(isFolder ? Icons.folder : Icons.description, color: isFolder ? ArgusColors.primary : Colors.grey),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isFolder ? 'Folder $index' : 'File_$index.txt', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text(isFolder ? '${index * 5} items' : '1.2 MB • Oct 24', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.more_vert, color: Colors.grey),
            ],
          ),
        );
      },
    );
  }
}
