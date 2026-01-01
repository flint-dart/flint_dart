import 'dart:async';
import 'package:flint_dart/logs.dart';
import 'package:worker_manager/worker_manager.dart';

/// Base class for tasks running in isolates
abstract class IsolateTask<T> {
  static bool _initialized = false;

  /// Initialize worker_manager once
  static Future<void> _initWorker() async {
    if (!_initialized) {
      workerManager.itSelf;
      _initialized = true;
    }
  }

  /// Task logic to implement
  /// This will run in a separate isolate
  FutureOr<T> performTask();

  /// Perform the task in an isolate
  /// Optional callbacks for completion and error
  Future<void> perform({
    void Function(T result)? onDone,
    void Function(Object error)? onError,
  }) async {
    await _initWorker();

    try {
      final result = await workerManager.execute<T>(() async {
        return await performTask();
      });

      if (onDone != null) {
        onDone(result);
      }
    } catch (e) {
      if (onError != null) {
        onError(e);
      } else {
        // Default error logging if no callback provided
        Log.debug("IsolateTask error: $e");
      }
    }
  }

  /// Clean up workers
  void dispose() {
    workerManager.dispose();
  }
}
