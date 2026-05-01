import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/file_model.dart';
import '../../../data/repositories/file_repository.dart';

final explorerProvider =
    StateNotifierProvider<ExplorerNotifier, List<FileModel>>(
  (ref) => ExplorerNotifier(),
);

class ExplorerNotifier extends StateNotifier<List<FileModel>> {
  ExplorerNotifier() : super([]);

  final FileRepository _repo = FileRepository();
  String currentPath = '/storage/emulated/0';

  void loadFiles([String? path]) {
    if (path != null) currentPath = path;
    state = _repo.getFiles(currentPath);
  }

  void navigateTo(String path) {
    loadFiles(path);
  }
}
