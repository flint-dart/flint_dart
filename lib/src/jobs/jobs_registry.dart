import 'package:flint_dart/src/jobs/flint_job_schedule.dart';
import 'package:flint_dart/src/jobs/flint_jobs.dart';
import 'package:flint_dart/src/jobs/queue_job.dart';

abstract class JobsRegistry {
  const JobsRegistry();

  Iterable<QueueJob> get jobs;

  Iterable<FlintSchedule> get schedules => const [];

  void registerJobs() {
    FlintJobs.register(jobs);
  }

  Future<void> registerSchedules() async {
    await FlintJobs.scheduleAll(schedules);
  }

  Future<void> registerAll() async {
    registerJobs();
    await registerSchedules();
  }
}
