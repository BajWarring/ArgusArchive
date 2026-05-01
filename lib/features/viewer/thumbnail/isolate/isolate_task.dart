import 'dart:typed_data';

class IsolateTask {
  final String id;
  final String path;
  final Function(Uint8List?) onDone;

  IsolateTask({
    required this.id,
    required this.path,
    required this.onDone,
  });
}
