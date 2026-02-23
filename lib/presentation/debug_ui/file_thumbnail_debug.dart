import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/enums/file_type.dart';
import '../../core/models/file_entry.dart';
import '../../adapters/local/local_storage_adapter.dart';
import '../../services/operations/apk_icon_service.dart';

class FileThumbnailDebug extends StatelessWidget {
  final FileEntry file;
  final dynamic adapter;
  final bool isDirectory;

  const FileThumbnailDebug({
    super.key,
    required this.file,
    required this.adapter,
    required this.isDirectory,
  });

  @override
  Widget build(BuildContext context) {
    if (isDirectory) return const Icon(Icons.folder, color: Colors.amber, size: 40);
    
    final ext = p.extension(file.path).toLowerCase();

    // 1. APK Thumbnails
    if (ext == '.apk' && adapter is LocalStorageAdapter) {
      return FutureBuilder<Uint8List?>(
        future: ApkIconService.getApkIcon(file.path),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             return const SizedBox(width: 40, height: 40, child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2)));
          }
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(snapshot.data!, width: 40, height: 40, fit: BoxFit.contain, cacheWidth: 120);
          }
          return const Icon(Icons.android, color: Colors.green, size: 40);
        }
      );
    }
    
    // Fallbacks for other archives
    if (ext == '.apk') return const Icon(Icons.android, color: Colors.green, size: 40);
    if (ext == '.zip' || ext == '.rar' || ext == '.7z') return const Icon(Icons.archive, color: Colors.orange, size: 40);

    // 2. SVG Thumbnails
    if (ext == '.svg') {
      if (adapter is LocalStorageAdapter) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SvgPicture.file(File(file.path), width: 40, height: 40, fit: BoxFit.cover, placeholderBuilder: (_) => const Icon(Icons.image, color: Colors.blue, size: 40)),
        );
      } else {
        return FutureBuilder<List<int>>(
          future: adapter.openRead(file.path).then((s) => s.expand((e) => e).toList()),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SvgPicture.memory(Uint8List.fromList(snapshot.data!), width: 40, height: 40, fit: BoxFit.cover, placeholderBuilder: (_) => const Icon(Icons.image, color: Colors.blue, size: 40)),
              );
            }
            return const Icon(Icons.image, color: Colors.blue, size: 40);
          }
        );
      }
    }

    // 3. Image Thumbnails (jpg, jpeg, png, gif, webp, bmp)
    final isImage = file.type == FileType.image || ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(ext);
    
    if (isImage) {
      if (adapter is LocalStorageAdapter) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.file(File(file.path), width: 40, height: 40, fit: BoxFit.cover, cacheWidth: 120, errorBuilder: (c,e,s) => const Icon(Icons.image, color: Colors.blue, size: 40)),
        );
      } else {
        return FutureBuilder<List<int>>(
          future: adapter.openRead(file.path).then((s) => s.expand((e) => e).toList()),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.memory(Uint8List.fromList(snapshot.data!), width: 40, height: 40, fit: BoxFit.cover, cacheWidth: 120, errorBuilder: (c,e,s) => const Icon(Icons.image, color: Colors.blue, size: 40)),
              );
            }
            return const Icon(Icons.image, color: Colors.blue, size: 40);
          }
        );
      }
    }
    
    return const Icon(Icons.insert_drive_file, color: Colors.tealAccent, size: 40);
  }
}
