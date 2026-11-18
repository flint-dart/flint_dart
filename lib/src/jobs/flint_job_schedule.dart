abstract class FlintSchedule {
  const FlintSchedule({
    required this.name,
    required this.jobType,
    this.queue = 'default',
    this.payload = const {},
    this.keyTemplate,
    this.enabled = true,
  });

  final String name;
  final String jobType;
  final String queue;
  final Map<String, dynamic> payload;
  final String? keyTemplate;
  final bool enabled;

  DateTime? nextRunAfter(DateTime? lastRunAt, DateTime now);

  String jobKey(DateTime scheduledAt) {
    final template = keyTemplate;
    if (template == null || template.trim().isEmpty) {
      return 'flint_schedule_${name}_${_bucket(scheduledAt)}';
    }
    return _renderTemplate(template, scheduledAt);
  }
}

class EverySchedule extends FlintSchedule {
  const EverySchedule({
    required super.name,
    required super.jobType,
    required this.every,
    super.queue,
    super.payload,
    super.keyTemplate,
    super.enabled,
    this.runImmediately = true,
  });

  final Duration every;
  final bool runImmediately;

  @override
  DateTime? nextRunAfter(DateTime? lastRunAt, DateTime now) {
    if (!enabled) return null;
    if (lastRunAt == null) return runImmediately ? now : now.add(every);
    final next = lastRunAt.add(every);
    return next.isAfter(now) ? next : now;
  }
}

String _renderTemplate(String template, DateTime date) {
  return template
      .replaceAll('{yyyy}', date.year.toString().padLeft(4, '0'))
      .replaceAll('{MM}', date.month.toString().padLeft(2, '0'))
      .replaceAll('{dd}', date.day.toString().padLeft(2, '0'))
      .replaceAll('{HH}', date.hour.toString().padLeft(2, '0'))
      .replaceAll('{mm}', date.minute.toString().padLeft(2, '0'))
      .replaceAll('{bucket}', _bucket(date));
}

String _bucket(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$year$month${day}_$hour$minute';
}
