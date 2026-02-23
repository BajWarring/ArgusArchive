import 'package:path_provider/path_provider.dart';

class StorageVolumesService {
  /// Returns a list of root paths for all mounted storage volumes (Internal + SD Cards).
  static Future<List<String>> getStorageRoots() async {
    List<String> roots = [];
    
    try {
      // getExternalStorageDirectories returns paths on ALL mounted physical volumes.
      // Example: 
      // 1. /storage/emulated/0/Android/data/com.app.argusarchive/files/Downloads
      // 2. /storage/A1B2-C3D4/Android/data/com.app.argusarchive/files/Downloads
      final directories = await getExternalStorageDirectories(type: StorageDirectory.downloads);
      
      if (directories != null) {
        for (var dir in directories) {
          final path = dir.path;
          
          // Slice the path at '/Android/' to get the true root directory of the drive
          if (path.contains('/Android/')) {
            final rootPath = path.split('/Android/')[0];
            if (!roots.contains(rootPath)) {
              roots.add(rootPath);
            }
          }
        }
      }
    } catch (e) {
      // Fallback if the query fails
      roots.add('/storage/emulated/0'); 
    }
    
    return roots;
  }
}
