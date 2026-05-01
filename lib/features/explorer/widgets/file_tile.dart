import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/file_model.dart';
import '../providers/explorer_provider.dart';
import '../../viewer/core/file_opener_service.dart';
import '../../viewer/thumbnail/widgets/thumbnail_widget.dart';
import 'file_actions_sheet.dart';

class FileTile extends ConsumerWidget {
  final FileModel file;
  final int index;

  const FileTile({super.key, required this.file, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: SizedBox(
        width: 50,
        height: 50,
        child: ThumbnailWidget(
          path: file.path,
          isDirectory: file.isDirectory,
          index: index,
        ),
      ),
      title: Text(file.name),
      subtitle: Text(
        file.isDirectory ? 'Folder' : '${file.size} bytes',
        style: const TextStyle(fontSize: 12, color: Colors.white54),
      ),
      onTap: () {
        if (file.isDirectory) {
          ref.read(explorerProvider.notifier).navigateTo(file.path);
        } else {
          FileOpenerService.open(context, file.path);
        }
      },
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          builder: (_) => FileActionsSheet(file: file),
        );
      },
    );
  }
}
