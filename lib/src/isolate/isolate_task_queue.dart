import 'dart:async';
import 'package:flint_dart/src/isolate/isolate_task.dart';
import 'package:worker_manager/worker_manager.dart';

/// Manager to schedule multiple isolate tasks
class IsolateTaskQueue {
  static bool _initialized = false;

  static Future<void> _initWorker() async {
    if (!_initialized) {
      workerManager.itSelf;
      _initialized = true;
    }
  }

  /// Schedule multiple tasks at once
  static Future<void> scheduleTasks(
    List<IsolateTask> tasks, {
    void Function(IsolateTask task, Object? result)? onDone,
    void Function(IsolateTask task, Object error)? onError,
  }) async {
    await _initWorker();

    for (final task in tasks) {
      unawaited(
        workerManager.execute(() async => task.performTask()).then((result) {
          if (onDone != null) onDone(task, result);
        }).catchError((e) {
          if (onError != null) onError(task, e);
        }),
      );
    }
  }
}
