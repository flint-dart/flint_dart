import 'dart:async';

import 'package:test/test.dart';
import 'package:flint_dart/src/isolate/isolate_task.dart';
import 'package:flint_dart/src/isolate/isolate_task_queue.dart';

class SumTask extends IsolateTask<int> {
  final int a;
  final int b;

  SumTask(this.a, this.b);

  @override
  Future<int> performTask() async {
    return a + b;
  }
}

class ErrorTask extends IsolateTask<int> {
  @override
  Future<int> performTask() async {
    throw Exception('boom');
  }
}

final List<int> _queueResults = <int>[];
final List<Object> _queueErrors = <Object>[];
Completer<void> _queueDone = Completer<void>();

void _resetQueueState() {
  _queueResults.clear();
  _queueErrors.clear();
  _queueDone = Completer<void>();
}

void _queueOnDone(IsolateTask task, Object? result) {
  _queueResults.add(result as int);
  if (_queueResults.length >= 2 && !_queueDone.isCompleted) {
    _queueDone.complete();
  }
}

void _queueOnError(IsolateTask task, Object error) {
  _queueErrors.add(error);
  if (!_queueDone.isCompleted) {
    _queueDone.completeError(StateError('IsolateTaskQueue error: $error'));
  }
}

void main() {
  test('IsolateTask perform returns result', () async {
    final completer = Completer<int>();

    await SumTask(2, 3).perform(
      onDone: completer.complete,
      onError: (e) => completer.completeError(e),
    );

    expect(await completer.future, 5);
  });

  test('IsolateTask perform reports error', () async {
    final completer = Completer<Object>();

    await ErrorTask().perform(
      onDone: (_) {},
      onError: completer.complete,
    );

    final err = await completer.future;
    expect(err, isA<Exception>());
  });

  test('IsolateTaskQueue schedules multiple tasks', () async {
    _resetQueueState();
    final tasks = [SumTask(1, 2), SumTask(3, 4)];

    await IsolateTaskQueue.scheduleTasks(
      tasks,
      onDone: _queueOnDone,
      onError: _queueOnError,
    );

    await _queueDone.future.timeout(const Duration(seconds: 10));
    if (_queueErrors.isNotEmpty) {
      fail('IsolateTaskQueue reported errors: $_queueErrors');
    }
    _queueResults.sort();
    expect(_queueResults, [3, 7]);
  });
}
