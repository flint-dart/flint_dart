import 'dart:async';

import 'package:flint_dart/flint_dart.dart';

typedef SecurityEventHandler = FutureOr<void> Function(
  SecurityEvent event,
);

class SecurityMiddleware extends Middleware {
  final SecurityConfig config;
  final SecurityEventHandler? onSecurityEvent;

  /// Stores recent 404 timestamps by client IP.
  final Map<String, List<DateTime>> _notFoundAttempts = {};

  /// Stores temporary blocks.
  final Map<String, DateTime> _blockedIps = {};

  Timer? _cleanupTimer;

  SecurityMiddleware({
    this.config = const SecurityConfig(),
    this.onSecurityEvent,
  }) {
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _cleanup(),
    );
  }

  @override
  Handler handle(Handler next) {
    return (Context ctx) async {
      final request = ctx.req;

      // IMPORTANT:
      // This must use the proxy-aware client IP,
      // not the raw proxy/socket IP.
      final ip = request.clientIpAddress;

      final path = request.path;
      final now = DateTime.now();

      // ------------------------------------------------------
      // BLOCKED IP CHECK
      // ------------------------------------------------------

      final blockedUntil = _blockedIps[ip];

      if (blockedUntil != null) {
        if (now.isBefore(blockedUntil)) {
          await _emit(
            SecurityEvent(
              type: SecurityEventType.blockedRequest,
              ipAddress: ip,
              path: path,
              blockedUntil: blockedUntil,
            ),
          );

          ctx.res?.status(403);

          return ctx.res?.json({
            'error': 'forbidden',
            'message': 'Access temporarily blocked.',
          });
        }

        // Block has expired.
        _blockedIps.remove(ip);

        await _emit(
          SecurityEvent(
            type: SecurityEventType.ipUnblocked,
            ipAddress: ip,
          ),
        );
      }

      // ------------------------------------------------------
      // PATH EXCLUSIONS
      // ------------------------------------------------------

      if (_isExcludedPath(path)) {
        return next(ctx);
      }

      // ------------------------------------------------------
      // SUSPICIOUS PATH DETECTION
      // ------------------------------------------------------

      if (_isSuspiciousPath(path)) {
        await _emit(
          SecurityEvent(
            type: SecurityEventType.suspiciousPath,
            ipAddress: ip,
            path: path,
          ),
        );
      }

      // ------------------------------------------------------
      // EXECUTE REQUEST
      // ------------------------------------------------------

      final response = await next(ctx);

      // ------------------------------------------------------
      final statusCode =
          response is Response ? response.statusCode : ctx.res?.statusCode;

      if (config.blockNotFoundAbuse && statusCode == 404) {
        await _recordNotFound(
          ip: ip,
          path: path,
          now: DateTime.now(),
        );
      }

      return response;
    };
  }

  Future<void> _recordNotFound({
    required String ip,
    required String path,
    required DateTime now,
  }) async {
    final attempts = _notFoundAttempts.putIfAbsent(
      ip,
      () => <DateTime>[],
    );

    // Sliding window:
    // remove attempts older than the configured window.
    attempts.removeWhere(
      (timestamp) => now.difference(timestamp) > config.notFoundWindow,
    );

    attempts.add(now);

    await _emit(
      SecurityEvent(
        type: SecurityEventType.notFound,
        ipAddress: ip,
        path: path,
        attempts: attempts.length,
      ),
    );

    if (attempts.length < config.maxNotFoundAttempts) {
      return;
    }

    final attemptCount = attempts.length;

    final blockedUntil = now.add(config.blockDuration);

    _blockedIps[ip] = blockedUntil;

    // Once blocked, previous attempts are no longer needed.
    _notFoundAttempts.remove(ip);

    Log.warning(
      '[Flint Security] Temporarily blocked IP $ip '
      'after $attemptCount 404 responses.',
    );

    await _emit(
      SecurityEvent(
        type: SecurityEventType.ipBlocked,
        ipAddress: ip,
        path: path,
        attempts: attemptCount,
        blockedUntil: blockedUntil,
      ),
    );
  }

  bool _isExcludedPath(String path) {
    final normalized = path.toLowerCase();

    for (final prefix in config.excludedPrefixes) {
      if (normalized.startsWith(
        prefix.toLowerCase(),
      )) {
        return true;
      }
    }

    return false;
  }

  bool _isSuspiciousPath(String path) {
    final normalized = path.toLowerCase();

    for (final prefix in config.suspiciousPathPrefixes) {
      if (normalized.startsWith(
        prefix.toLowerCase(),
      )) {
        return true;
      }
    }

    return false;
  }

  /// Returns whether an IP is currently blocked.
  bool isBlocked(String ip) {
    final blockedUntil = _blockedIps[ip];

    if (blockedUntil == null) {
      return false;
    }

    if (DateTime.now().isAfter(blockedUntil)) {
      _blockedIps.remove(ip);
      return false;
    }

    return true;
  }

  /// Manually block an IP.
  Future<void> blockIp(
    String ip, {
    Duration? duration,
  }) async {
    final blockedUntil = DateTime.now().add(
      duration ?? config.blockDuration,
    );

    _blockedIps[ip] = blockedUntil;
    _notFoundAttempts.remove(ip);

    await _emit(
      SecurityEvent(
        type: SecurityEventType.ipBlocked,
        ipAddress: ip,
        blockedUntil: blockedUntil,
      ),
    );

    Log.warning(
      '[Flint Security] Manually blocked IP $ip.',
    );
  }

  /// Manually unblock an IP.
  Future<void> unblockIp(String ip) async {
    final wasBlocked = _blockedIps.remove(ip);

    _notFoundAttempts.remove(ip);

    if (wasBlocked != null) {
      await _emit(
        SecurityEvent(
          type: SecurityEventType.ipUnblocked,
          ipAddress: ip,
        ),
      );
    }
  }

  /// Returns the block expiry for an IP.
  DateTime? blockedUntil(String ip) {
    if (!isBlocked(ip)) {
      return null;
    }

    return _blockedIps[ip];
  }

  /// Current number of temporarily blocked IPs.
  int get blockedIpCount {
    _cleanup();
    return _blockedIps.length;
  }

  /// Current blocked IP addresses.
  Set<String> get blockedIps {
    _cleanup();

    return Set.unmodifiable(
      _blockedIps.keys,
    );
  }

  /// Number of current 404 attempts for an IP
  /// inside the configured sliding window.
  int notFoundAttempts(String ip) {
    _cleanupAttempts(ip);

    return _notFoundAttempts[ip]?.length ?? 0;
  }

  void _cleanupAttempts(String ip) {
    final attempts = _notFoundAttempts[ip];

    if (attempts == null) {
      return;
    }

    final now = DateTime.now();

    attempts.removeWhere(
      (timestamp) => now.difference(timestamp) > config.notFoundWindow,
    );

    if (attempts.isEmpty) {
      _notFoundAttempts.remove(ip);
    }
  }

  void _cleanup() {
    final now = DateTime.now();

    _blockedIps.removeWhere(
      (_, blockedUntil) => now.isAfter(blockedUntil),
    );

    final ips = _notFoundAttempts.keys.toList();

    for (final ip in ips) {
      _cleanupAttempts(ip);
    }
  }

  Future<void> _emit(
    SecurityEvent event,
  ) async {
    final handler = onSecurityEvent;

    if (handler == null) {
      return;
    }

    try {
      await handler(event);
    } catch (e, stack) {
      Log.warning(
        '[Flint Security] '
        'Security event handler failed',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Stop the internal cleanup timer.
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    _notFoundAttempts.clear();
    _blockedIps.clear();
  }
}
