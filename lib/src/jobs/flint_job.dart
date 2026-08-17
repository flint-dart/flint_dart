import 'dart:async';

import 'package:flint_dart/src/jobs/flint_job_context.dart';

abstract class FlintJob {
  String get type;

  String get queue => 'default';

  int get maxAttempts => 3;

  Duration? get timeout => null;

  Duration? retryDelay(int attempt) => Duration(minutes: attempt * 5);

  FutureOr<void> handle(FlintJobContext ctx);
}
