// auth_config.dart
class AuthConfig {
  // Database table configuration
  final String table;
  final String emailColumn;
  final String passwordColumn;
  final String? nameColumn;
  final String? providerColumn;
  final String? providerIdColumn;

  // OAuth Provider configurations
  final String? googleClientId;
  final String? googleClientSecret;

  final String? githubClientId;
  final String? githubClientSecret;

  final String? facebookClientId;
  final String? facebookClientSecret;

  final String? appleClientId;
  final String? appleTeamId;
  final String? appleKeyId;
  final String? applePrivateKey;

  // Application settings
  final String redirectBase;
  final String? jwtSecret;

  // Security settings
  final int jwtExpiryHours;
  final bool requireEmailVerification;
  final int passwordMinLength;

  AuthConfig({
    // Database configuration
    required this.table,
    required this.emailColumn,
    required this.passwordColumn,
    this.nameColumn,
    this.providerColumn,
    this.providerIdColumn,

    // Google OAuth
    this.googleClientId,
    this.googleClientSecret,

    // GitHub OAuth
    this.githubClientId,
    this.githubClientSecret,

    // Facebook OAuth
    this.facebookClientId,
    this.facebookClientSecret,

    // Apple Sign In
    this.appleClientId,
    this.appleTeamId,
    this.appleKeyId,
    this.applePrivateKey,

    // Application settings
    required this.redirectBase,
    this.jwtSecret,

    // Security settings
    this.jwtExpiryHours = 24,
    this.requireEmailVerification = false,
    this.passwordMinLength = 6,
  });

  // Helper methods to check if providers are configured
  bool get isGoogleConfigured =>
      googleClientId != null &&
      googleClientId!.isNotEmpty &&
      googleClientSecret != null &&
      googleClientSecret!.isNotEmpty;

  bool get isGitHubConfigured =>
      githubClientId != null &&
      githubClientId!.isNotEmpty &&
      githubClientSecret != null &&
      githubClientSecret!.isNotEmpty;

  bool get isFacebookConfigured =>
      facebookClientId != null &&
      facebookClientId!.isNotEmpty &&
      facebookClientSecret != null &&
      facebookClientSecret!.isNotEmpty;

  bool get isAppleConfigured =>
      appleClientId != null &&
      appleClientId!.isNotEmpty &&
      appleTeamId != null &&
      appleTeamId!.isNotEmpty &&
      appleKeyId != null &&
      appleKeyId!.isNotEmpty &&
      applePrivateKey != null &&
      applePrivateKey!.isNotEmpty;

  // Get all configured providers
  Map<String, bool> get configuredProviders => {
        'google': isGoogleConfigured,
        'github': isGitHubConfigured,
        'facebook': isFacebookConfigured,
        'apple': isAppleConfigured,
      };

  // Validate configuration
  Map<String, dynamic> validate() {
    final errors = <String>[];
    final warnings = <String>[];

    // Required database configuration
    if (table.isEmpty) errors.add('AUTH_TABLE is required');
    if (emailColumn.isEmpty) errors.add('AUTH_EMAIL_COLUMN is required');
    if (passwordColumn.isEmpty) errors.add('AUTH_PASSWORD_COLUMN is required');

    // Provider configuration warnings
    if (!isGoogleConfigured) {
      warnings.add(
          'Google OAuth not configured (GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET required)');
    }
    if (!isGitHubConfigured) {
      warnings.add(
          'GitHub OAuth not configured (GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET required)');
    }
    if (!isFacebookConfigured) {
      warnings.add(
          'Facebook OAuth not configured (FACEBOOK_CLIENT_ID and FACEBOOK_CLIENT_SECRET required)');
    }
    if (!isAppleConfigured) {
      warnings.add(
          'Apple Sign In not configured (APPLE_CLIENT_ID, APPLE_TEAM_ID, APPLE_KEY_ID, and APPLE_PRIVATE_KEY required)');
    }

    // JWT security warning
    if (jwtSecret == null ||
        jwtSecret!.isEmpty ||
        jwtSecret == 'your-default-jwt-secret-change-in-production') {
      warnings
          .add('Using default JWT secret - change JWT_SECRET in production');
    }

    return {
      'valid': errors.isEmpty,
      'errors': errors,
      'warnings': warnings,
      'configuredProviders': configuredProviders,
    };
  }

  // Copy with method for overriding settings
  AuthConfig copyWith({
    String? table,
    String? emailColumn,
    String? passwordColumn,
    String? nameColumn,
    String? providerColumn,
    String? providerIdColumn,
    String? googleClientId,
    String? googleClientSecret,
    String? githubClientId,
    String? githubClientSecret,
    String? facebookClientId,
    String? facebookClientSecret,
    String? appleClientId,
    String? appleTeamId,
    String? appleKeyId,
    String? applePrivateKey,
    String? redirectBase,
    String? jwtSecret,
    int? jwtExpiryHours,
    bool? requireEmailVerification,
    int? passwordMinLength,
  }) {
    return AuthConfig(
      table: table ?? this.table,
      emailColumn: emailColumn ?? this.emailColumn,
      passwordColumn: passwordColumn ?? this.passwordColumn,
      nameColumn: nameColumn ?? this.nameColumn,
      providerColumn: providerColumn ?? this.providerColumn,
      providerIdColumn: providerIdColumn ?? this.providerIdColumn,
      googleClientId: googleClientId ?? this.googleClientId,
      googleClientSecret: googleClientSecret ?? this.googleClientSecret,
      githubClientId: githubClientId ?? this.githubClientId,
      githubClientSecret: githubClientSecret ?? this.githubClientSecret,
      facebookClientId: facebookClientId ?? this.facebookClientId,
      facebookClientSecret: facebookClientSecret ?? this.facebookClientSecret,
      appleClientId: appleClientId ?? this.appleClientId,
      appleTeamId: appleTeamId ?? this.appleTeamId,
      appleKeyId: appleKeyId ?? this.appleKeyId,
      applePrivateKey: applePrivateKey ?? this.applePrivateKey,
      redirectBase: redirectBase ?? this.redirectBase,
      jwtSecret: jwtSecret ?? this.jwtSecret,
      jwtExpiryHours: jwtExpiryHours ?? this.jwtExpiryHours,
      requireEmailVerification:
          requireEmailVerification ?? this.requireEmailVerification,
      passwordMinLength: passwordMinLength ?? this.passwordMinLength,
    );
  }

  @override
  String toString() {
    return '''
AuthConfig {
  table: $table,
  emailColumn: $emailColumn,
  passwordColumn: $passwordColumn,
  nameColumn: $nameColumn,
  providerColumn: $providerColumn,
  providerIdColumn: $providerIdColumn,
  googleClientId: ${googleClientId != null ? '***' : 'null'},
  googleClientSecret: ${googleClientSecret != null ? '***' : 'null'},
  githubClientId: ${githubClientId != null ? '***' : 'null'},
  githubClientSecret: ${githubClientSecret != null ? '***' : 'null'},
  facebookClientId: ${facebookClientId != null ? '***' : 'null'},
  facebookClientSecret: ${facebookClientSecret != null ? '***' : 'null'},
  appleClientId: ${appleClientId != null ? '***' : 'null'},
  appleTeamId: ${appleTeamId != null ? '***' : 'null'},
  appleKeyId: ${appleKeyId != null ? '***' : 'null'},
  applePrivateKey: ${applePrivateKey != null ? '***' : 'null'},
  redirectBase: $redirectBase,
  jwtSecret: ${jwtSecret != null ? '***' : 'null'},
  jwtExpiryHours: $jwtExpiryHours,
  requireEmailVerification: $requireEmailVerification,
  passwordMinLength: $passwordMinLength,
  configuredProviders: $configuredProviders
}
''';
  }
}
