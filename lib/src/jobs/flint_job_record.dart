class FlintJobStatus {
  static const pending = 'PENDING';
  static const running = 'RUNNING';
  static const completed = 'COMPLETED';
  static const failed = 'FAILED';
  static const cancelled = 'CANCELLED';
}

class FlintJobRecord {
  const FlintJobRecord({
    required this.id,
    required this.type,
    required this.queue,
    required this.payload,
    required this.status,
    required this.attempts,
    required this.maxAttempts,
    required this.createdAt,
    this.jobKey,
    this.runAt,
    this.lockedAt,
    this.lockedBy,
    this.startedAt,
    this.finishedAt,
    this.lastError,
    this.metadata = const {},
  });

  final String id;
  final String type;
  final String queue;
  final Map<String, dynamic> payload;
  final String? jobKey;
  final String status;
  final int attempts;
  final int maxAttempts;
  final DateTime? runAt;
  final DateTime? lockedAt;
  final String? lockedBy;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? lastError;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  FlintJobRecord copyWith({
    String? id,
    String? type,
    String? queue,
    Map<String, dynamic>? payload,
    String? jobKey,
    bool clearJobKey = false,
    String? status,
    int? attempts,
    int? maxAttempts,
    DateTime? runAt,
    bool clearRunAt = false,
    DateTime? lockedAt,
    bool clearLockedAt = false,
    String? lockedBy,
    bool clearLockedBy = false,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? finishedAt,
    bool clearFinishedAt = false,
    String? lastError,
    bool clearLastError = false,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return FlintJobRecord(
      id: id ?? this.id,
      type: type ?? this.type,
      queue: queue ?? this.queue,
      payload: payload ?? this.payload,
      jobKey: clearJobKey ? null : (jobKey ?? this.jobKey),
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      runAt: clearRunAt ? null : (runAt ?? this.runAt),
      lockedAt: clearLockedAt ? null : (lockedAt ?? this.lockedAt),
      lockedBy: clearLockedBy ? null : (lockedBy ?? this.lockedBy),
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      finishedAt: clearFinishedAt ? null : (finishedAt ?? this.finishedAt),
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
