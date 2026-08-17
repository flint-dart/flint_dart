class FlintJobScheduleRecord {
  const FlintJobScheduleRecord({
    required this.id,
    required this.name,
    required this.jobType,
    required this.queue,
    required this.payload,
    required this.enabled,
    required this.createdAt,
    this.keyTemplate,
    this.lastRunAt,
    this.nextRunAt,
    this.lastError,
    this.metadata = const {},
  });

  final String id;
  final String name;
  final String jobType;
  final String queue;
  final Map<String, dynamic> payload;
  final String? keyTemplate;
  final bool enabled;
  final DateTime? lastRunAt;
  final DateTime? nextRunAt;
  final String? lastError;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  FlintJobScheduleRecord copyWith({
    String? id,
    String? name,
    String? jobType,
    String? queue,
    Map<String, dynamic>? payload,
    String? keyTemplate,
    bool clearKeyTemplate = false,
    bool? enabled,
    DateTime? lastRunAt,
    bool clearLastRunAt = false,
    DateTime? nextRunAt,
    bool clearNextRunAt = false,
    String? lastError,
    bool clearLastError = false,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return FlintJobScheduleRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      jobType: jobType ?? this.jobType,
      queue: queue ?? this.queue,
      payload: payload ?? this.payload,
      keyTemplate: clearKeyTemplate ? null : (keyTemplate ?? this.keyTemplate),
      enabled: enabled ?? this.enabled,
      lastRunAt: clearLastRunAt ? null : (lastRunAt ?? this.lastRunAt),
      nextRunAt: clearNextRunAt ? null : (nextRunAt ?? this.nextRunAt),
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
