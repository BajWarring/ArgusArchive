import 'dart:isolate';
import '../services/thumbnail_generator.dart';

/// Entry point for each isolate worker in the pool.
/// Receives tasks via [SendPort] and sends results back.
void isolateEntry(SendPort mainSendPort) async {
  final port = ReceivePort();
  mainSendPort.send(port.sendPort);

  final cancelled = <String>{};

  await for (final msg in port) {
    if (msg is Map) {
      // Cancellation signal
      if (msg['cancel'] == true) {
        cancelled.add(msg['id'] as String);
        continue;
      }

      // Task signal
      if (msg['task'] == true) {
        final id = msg['id'] as String;
        final path = msg['path'] as String;

        if (cancelled.contains(id)) continue;

        final bytes = await ThumbnailGenerator.generateImage(path);

        if (cancelled.contains(id)) continue; // check after work

        mainSendPort.send({'id': id, 'bytes': bytes});
      }
    }
  }
}
