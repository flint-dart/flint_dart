import 'package:flint_dart/src/jobs/queue_job.dart';

@Deprecated(
  'Use QueueJob instead. FlintJob is deprecated and kept only for '
  'backward compatibility.',
)
abstract class FlintJob extends QueueJob {}
