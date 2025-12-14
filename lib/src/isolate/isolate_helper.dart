import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/session.dart';

/// A pool of isolates to handle tasks concurrently.
///
/// This helper allows running CPU-intensive or long-running tasks in isolates,
/// efficiently distributing them across a fixed number of workers.
/// Supports running arbitrary functions or Flint Dart request handlers.
class IsolatePoolHelper {
  /// Number of isolates in the pool.
  final int poolSize;

  final List<_PoolWorker> _workers = [];
  final Queue<_TaskRequest> _taskQueue = Queue();
  bool _initialized = false;

  /// Creates a new pool with the given [poolSize].
  /// Defaults to 2 isolates if not specified.
  IsolatePoolHelper({this.poolSize = 2});

  /// Initializes the pool by spawning the isolates.
  ///
  /// This method is automatically called when the first task is submitted.
  Future<void> init() async {
    if (_initialized) return;
    for (var i = 0; i < poolSize; i++) {
      final worker = _PoolWorker();
      await worker.init();
      _workers.add(worker);
    }
    _initialized = true;
  }

  /// Runs a function [task] with parameters [params] in the isolate pool.
  ///
  /// If all isolates are busy, the task is queued until a worker becomes available.
  /// Optionally, a [timeout] can be specified.
  ///
  /// Returns a [Future] that completes with the result of the task.
  Future<T> run<T, P>(Future<T> Function(P params) task, P params,
      {Duration? timeout}) async {
    await init(); // Ensure pool is ready

    final completer = Completer<T>();
    final taskReq = _TaskRequest(task, params, completer, timeout);

    // Assign to idle worker if available
    final idleWorker = _workers.firstWhereOrNull((w) => w.idle);
    if (idleWorker != null) {
      idleWorker.runTask(taskReq);
    } else {
      // Otherwise queue the task
      _taskQueue.add(taskReq);
    }

    return completer.future;
  }

  /// Runs a Flint Dart [Request] handler in an isolate.
  ///
  /// Useful for offloading HTTP request processing to isolates for CPU-heavy tasks.
  /// The response [res] is sent automatically when the task completes.
  ///
  /// Optionally, a [timeout] can be specified.
  Future<void> runRequest(
    Future<Response> Function(Request req) handler,
    Request req,
    Response res, {
    Duration? timeout,
  }) async {
    try {
      final response = await run<Response, Map<String, dynamic>>(
        (params) async {
          final reqData = params['req'] as Request;
          return await handler(reqData);
        },
        {'req': req},
        timeout: timeout,
      );

      // Replace with actual Response sending logic
      await res.sendStreamed(response);
    } catch (e, stack) {
      res.status(500).respond({'error': e.toString()});
      print('IsolatePoolHelper.runRequest error: $e\n$stack');
    }
  }

  /// Assigns queued tasks to any idle workers.
  void _assignQueuedTasks() {
    while (_taskQueue.isNotEmpty) {
      final idleWorker = _workers.firstWhereOrNull((w) => w.idle);
      if (idleWorker == null) break;
      final task = _taskQueue.removeFirst();
      idleWorker.runTask(task);
    }
  }
}

/// Internal class representing a worker isolate in the pool.
class _PoolWorker {
  late Isolate _isolate;
  late SendPort _sendPort;
  final ReceivePort _receivePort = ReceivePort();
  bool idle = true;

  /// Initializes the worker by spawning an isolate.
  Future<void> init() async {
    final completer = Completer<void>();
    _receivePort.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
        completer.complete();
      }
    });

    _isolate = await Isolate.spawn(_workerEntry, _receivePort.sendPort);
    return completer.future;
  }

  /// Runs a task [_TaskRequest] in this worker.
  void runTask(_TaskRequest task) {
    idle = false;
    final taskPort = ReceivePort();

    taskPort.listen((msg) {
      if (msg is _TaskResult) {
        if (msg.error != null) {
          task.completer.completeError(msg.error!, msg.stack);
        } else {
          task.completer.complete(msg.result as dynamic);
        }
        taskPort.close();
        idle = true;
      }
    });

    _sendPort.send({'task': task, 'replyTo': taskPort.sendPort});
  }

  /// Entry point for the spawned isolate.
  static void _workerEntry(SendPort sendPort) {
    final port = ReceivePort();
    sendPort.send(port.sendPort);

    port.listen((message) async {
      final task = message['task'] as _TaskRequest;
      final reply = message['replyTo'] as SendPort;

      try {
        final result = await task.task(task.params);
        reply.send(_TaskResult(result: result));
      } catch (e, stack) {
        reply.send(_TaskResult(error: e, stack: stack));
      }
    });
  }
}

/// Internal wrapper for a task submitted to the pool.
class _TaskRequest<P, T> {
  /// The function to run.
  final Future<T> Function(P params) task;

  /// Parameters for the task.
  final P params;

  /// Completer to signal task completion.
  final Completer<T> completer;

  /// Optional timeout for the task.
  final Duration? timeout;

  _TaskRequest(this.task, this.params, this.completer, this.timeout);
}

/// Represents the result of a task executed in a worker.
class _TaskResult {
  /// Task result (if successful).
  final dynamic result;

  /// Error thrown (if any).
  final dynamic error;

  /// Stack trace for error (if any).
  final StackTrace? stack;

  _TaskResult({this.result, this.error, this.stack});
}
