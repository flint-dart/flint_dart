enum SecurityEventType {
  notFound,
  suspiciousPath,
  ipBlocked,
  blockedRequest,
  ipUnblocked,
}

class SecurityEvent {
  final SecurityEventType type;
  final String ipAddress;
  final String? path;
  final int? attempts;
  final DateTime timestamp;
  final DateTime? blockedUntil;

  SecurityEvent({
    required this.type,
    required this.ipAddress,
    this.path,
    this.attempts,
    this.blockedUntil,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'SecurityEvent('
        'type: ${type.name}, '
        'ip: $ipAddress, '
        'path: $path, '
        'attempts: $attempts, '
        'blockedUntil: $blockedUntil'
        ')';
  }
}
