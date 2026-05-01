import 'dart:isolate';
import 'isolate_entry.dart';

/// Wraps a single spawned [Isolate] and tracks its workload.
class Worker {
  late Isolate isolate;
  late SendPort sendPort;
  final ReceivePort receivePort = ReceivePort();
  int activeTasks = 0;

  Future<void> init() async {
    isolate = await Isolate.spawn(
      isolateEntry,
      receivePort.sendPort,
    );
    sendPort = await receivePort.first;
  }

  void dispose() {
    isolate.kill(priority: Isolate.immediate);
    receivePort.close();
  }
}
