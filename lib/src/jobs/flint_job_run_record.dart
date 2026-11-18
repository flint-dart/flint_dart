class FlintJobRunRecord {
  const FlintJobRunRecord({
    required this.id,
    required this.jobId,
    required this.type,
    required this.queue,
    required this.status,
    required this.attempt,
    required this.startedAt,
    this.finishedAt,
    this.elapsedMs,
    this.error,
    this.workerId,
    this.metadata = const {},
  });

  final String id;
  final String jobId;
  final String type;
  final String queue;
  final String status;
  final int attempt;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int? elapsedMs;
  final String? error;
  final String? workerId;
  final Map<String, dynamic> metadata;

  FlintJobRunRecord copyWith({
    String? id,
    String? jobId,
    String? type,
    String? queue,
    String? status,
    int? attempt,
    DateTime? startedAt,
    DateTime? finishedAt,
    int? elapsedMs,
    String? error,
    bool clearError = false,
    String? workerId,
    Map<String, dynamic>? metadata,
  }) {
    return FlintJobRunRecord(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      type: type ?? this.type,
      queue: queue ?? this.queue,
      status: status ?? this.status,
      attempt: attempt ?? this.attempt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      error: clearError ? null : (error ?? this.error),
      workerId: workerId ?? this.workerId,
      metadata: metadata ?? this.metadata,
    );
  }
}
