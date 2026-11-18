class SecurityConfig {
  /// Enables automatic blocking when an IP generates
  /// too many 404 responses.
  final bool blockNotFoundAbuse;

  /// Maximum number of 404 responses allowed inside
  /// [notFoundWindow].
  final int maxNotFoundAttempts;

  /// Sliding time window used to count 404 responses.
  final Duration notFoundWindow;

  /// Duration an abusive IP remains blocked.
  final Duration blockDuration;

  /// Paths that should be considered suspicious.
  ///
  /// Suspicious requests are reported through the security
  /// event callback but are not automatically blocked unless
  /// they also trigger the normal abuse rules.
  final List<String> suspiciousPathPrefixes;

  /// Paths that should bypass 404 abuse detection.
  ///
  /// Useful for routes where 404 responses may be normal.
  final List<String> excludedPrefixes;

  const SecurityConfig({
    this.blockNotFoundAbuse = true,
    this.maxNotFoundAttempts = 10,
    this.notFoundWindow = const Duration(minutes: 1),
    this.blockDuration = const Duration(hours: 1),
    this.suspiciousPathPrefixes = const [],
    this.excludedPrefixes = const [],
  });

  /// Recommended defaults for public production applications.
  factory SecurityConfig.production({
    int maxNotFoundAttempts = 10,
    Duration notFoundWindow = const Duration(minutes: 1),
    Duration blockDuration = const Duration(hours: 1),
    List<String> suspiciousPathPrefixes = const [],
    List<String> excludedPrefixes = const [],
  }) {
    return SecurityConfig(
      blockNotFoundAbuse: true,
      maxNotFoundAttempts: maxNotFoundAttempts,
      notFoundWindow: notFoundWindow,
      blockDuration: blockDuration,
      suspiciousPathPrefixes: suspiciousPathPrefixes,
      excludedPrefixes: excludedPrefixes,
    );
  }

  /// Security monitoring without automatic 404 blocking.
  factory SecurityConfig.monitorOnly({
    List<String> suspiciousPathPrefixes = const [],
    List<String> excludedPrefixes = const [],
  }) {
    return SecurityConfig(
      blockNotFoundAbuse: false,
      suspiciousPathPrefixes: suspiciousPathPrefixes,
      excludedPrefixes: excludedPrefixes,
    );
  }
}
