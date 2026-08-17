import 'package:flint_dart/src/jobs/flint_job_record.dart';
import 'package:flint_dart/src/jobs/flint_job_store.dart';

class FlintJobContext {
  FlintJobContext({
    required FlintJobStore store,
    required FlintJobRecord record,
    required this.attempt,
  })  : _store = store,
        _record = record,
        payload = Map<String, dynamic>.from(record.payload);

  final FlintJobStore _store;
  FlintJobRecord _record;

  FlintJobRecord get record => _record;
  final Map<String, dynamic> payload;
  final int attempt;
  bool get finished => _finished;

  bool _finished = false;

  Future<void> complete({Map<String, dynamic>? payload}) async {
    _record = await _store.complete(
      _record,
      payload: payload ?? this.payload,
    );
    _finished = true;
  }

  Future<void> fail(Object error, {bool retry = true}) async {
    _record = await _store.fail(
      _record,
      error: error.toString(),
      retry: retry,
    );
    _finished = true;
  }

  Future<void> release({required DateTime nextRunAt, String? reason}) async {
    _record = await _store.release(
      _record,
      nextRunAt: nextRunAt,
      reason: reason,
      payload: payload,
    );
    _finished = true;
  }

  Future<void> log(String message, {Map<String, dynamic>? metadata}) async {
    await _store.log(_record, message, metadata: metadata);
  }
}
