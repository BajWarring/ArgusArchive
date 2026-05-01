import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/file_ops_service.dart';

final fileOpsProvider = Provider<FileOpsService>((ref) {
  return FileOpsService();
});
