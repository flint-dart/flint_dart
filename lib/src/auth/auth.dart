// auth.dart
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flint_dart/db.dart';
import 'package:flint_dart/security.dart';
import 'package:flint_dart/src/auth/auth_config.dart';
import 'package:flint_dart/src/auth/providers/google_provider.dart';
import 'package:flint_dart/src/auth/providers/github_provider.dart';
import 'package:flint_dart/src/auth/providers/facebook_provider.dart';
import 'package:flint_dart/src/auth/providers/apple_provider.dart';
import 'package:flint_dart/src/database/orm/query_builder.dart';
import 'package:flint_dart/src/env_parser.dart';
import 'package:flint_dart/src/error/auth_exception.dart';

class Auth {
  static final AuthConfig _config = _loadConfig();

  static AuthConfig get config => _config;

  static AuthConfig _loadConfig() {
    final table = FlintEnv.get('AUTH_TABLE', 'users');
    final emailColumn = FlintEnv.get('AUTH_EMAIL_COLUMN', 'email');
    final passwordColumn = FlintEnv.get('AUTH_PASSWORD_COLUMN', 'password');
    final nameColumn = FlintEnv.get('AUTH_NAME_COLUMN', 'name');
    final providerColumn = FlintEnv.get('AUTH_PROVIDER_COLUMN', 'provider');
    final providerIdColumn =
        FlintEnv.get('AUTH_PROVIDER_ID_COLUMN', 'provider_id');
    final requireEmailVerification =
        FlintEnv.getBool("REQUIRE_EMAIL_VERIFICATION", false);
    final passwordMinLength = FlintEnv.getInt('PASSWORD_MIN_LENGTH', 6);
    final jwtExpiryHours = FlintEnv.getInt('JWT_EXPIRY_HOURS', 24);
    final googleClientId = FlintEnv.get('GOOGLE_CLIENT_ID', '');
    final googleClientSecret = FlintEnv.get('GOOGLE_CLIENT_SECRET', '');
    final githubClientId = FlintEnv.get('GITHUB_CLIENT_ID', '');
    final githubClientSecret = FlintEnv.get('GITHUB_CLIENT_SECRET', '');
    final facebookClientId = FlintEnv.get('FACEBOOK_CLIENT_ID', '');
    final facebookClientSecret = FlintEnv.get('FACEBOOK_CLIENT_SECRET', '');
    final appleClientId = FlintEnv.get('APPLE_CLIENT_ID', '');
    final appleTeamId = FlintEnv.get('APPLE_TEAM_ID', '');
    final appleKeyId = FlintEnv.get('APPLE_KEY_ID', '');
    final applePrivateKey = FlintEnv.get('APPLE_PRIVATE_KEY', '');

    final redirectBase = FlintEnv.get('REDIRECT_BASE', 'http://localhost:3000');
    final jwtSecret = FlintEnv.get(
        'JWT_SECRET', 'your-default-jwt-secret-change-in-production');

    return AuthConfig(
        table: table,
        emailColumn: emailColumn,
        passwordColumn: passwordColumn,
        nameColumn: nameColumn,
        providerColumn: providerColumn,
        providerIdColumn: providerIdColumn,
        googleClientId: googleClientId,
        googleClientSecret: googleClientSecret,
        githubClientId: githubClientId,
        githubClientSecret: githubClientSecret,
        facebookClientId: facebookClientId,
        facebookClientSecret: facebookClientSecret,
        appleClientId: appleClientId,
        appleTeamId: appleTeamId,
        appleKeyId: appleKeyId,
        applePrivateKey: applePrivateKey,
        redirectBase: redirectBase,
        jwtSecret: jwtSecret,
        jwtExpiryHours: jwtExpiryHours,
        passwordMinLength: passwordMinLength,
        requireEmailVerification: requireEmailVerification);
  }

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final qb = QueryBuilder(table: _config.table);
    final user =
        await qb.where(_config.emailColumn, '=', email).limit(1).first();

    if (user == null) {
      throw AuthException('Invalid email or password');
    }

    final hashedPassword = user[_config.passwordColumn] as String;
    final isMatch = Hashing().verify(password, hashedPassword);

    if (!isMatch) {
      throw AuthException('Invalid email or password');
    }

    if (_config.requireEmailVerification && user['email_verified_at'] == null) {
      throw AuthException('Email verification required.');
    }

    final cleanUser = _sanitizeUserData(user);

    // ✅ Create JWT token with expiry
    final jwt = JWT({
      'id': cleanUser['id'],
      'email': cleanUser[_config.emailColumn],
    });

    final token = jwt.sign(
      SecretKey(_config.jwtSecret!),
      expiresIn: Duration(hours: _config.jwtExpiryHours),
    );

    return {
      'user': cleanUser,
      'token': token,
    };
  }

  /// Register new user - returns user data
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? name,
    Map<String, dynamic>? additionalData,
  }) async {
    final qb = QueryBuilder(table: config.table);

    // Check if user exists
    final existing = await qb.where(config.emailColumn, '=', email).first();

    if (existing != null) {
      throw AuthException('User already exists with this email');
    }

    if (password.length < _config.passwordMinLength) {
      throw AuthException(
        'Password must be at least ${_config.passwordMinLength} characters long.',
      );
    }
    // Hash password
    final hashedPassword = Hashing().hash(password);

    // Build data safely - only include columns that exist
    final data = await _buildSafeUserData(
      email: email,
      hashedPassword: hashedPassword,
      name: name,
      additionalData: additionalData,
    );
    // Insert user
    await QueryBuilder(table: config.table).insert(data);

    // Get created user
    final user = await QueryBuilder(table: config.table)
        .where(config.emailColumn, '=', email)
        .first();

    if (user == null) {
      throw AuthException('User could not be retrieved after registration.');
    }

    return _sanitizeUserData(user);
  }

  /// Generate password reset token
  static Future<String?> generatePasswordResetToken(String email) async {
    final qb = QueryBuilder(table: config.table);
    final user = await qb.where(config.emailColumn, '=', email).first();

    if (user == null) {
      return null; // Don't reveal if user exists
    }
    await ensureFrameworkTablesExist();
    // Generate a secure random token
    final token = Hashing()
        .hash(DateTime.now().millisecondsSinceEpoch.toString() + email);
    final tokenHash =
        Hashing().hash(token); // Store hashed version for security

    // Store token in database with expiry (1 hour)
    final expiresAt = DateTime.now().add(Duration(hours: 1)).toIso8601String();

    await QueryBuilder(table: 'password_reset_tokens').insert({
      'email': email,
      'token': tokenHash,
      'expires_at': expiresAt,
      'created_at': DateTime.now().toIso8601String(),
    });

    return token;
  }

  /// Reset password using token
  static Future<bool> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    if (newPassword.length < _config.passwordMinLength) {
      throw AuthException(
        'Password must be at least ${_config.passwordMinLength} characters long.',
      );
    }
    ensureFrameworkTablesExist();

    final tokenHash = Hashing().hash(token);
    final qb = QueryBuilder(table: 'password_reset_tokens');

    final tokenRecord = await qb
        .where('token', '=', tokenHash)
        .where('expires_at', '>', DateTime.now().toIso8601String())
        .first();

    if (tokenRecord == null) {
      return false; // Invalid or expired token
    }

    final email = tokenRecord['email'] as String;
    final hashedPassword = Hashing().hash(newPassword);

    // Update user password
    await QueryBuilder(table: config.table)
        .where(config.emailColumn, '=', email)
        .update({
      config.passwordColumn: hashedPassword,
    });

    // Delete used token
    await qb.where('token', '=', tokenHash).delete();

    return true;
  }

  /// Generate email verification token
  static Future<String?> generateEmailVerificationToken(String email) async {
    final qb = QueryBuilder(table: config.table);
    final user = await qb.where(config.emailColumn, '=', email).first();

    if (user == null) {
      return null; // Don't reveal if user exists
    }
    await ensureFrameworkTablesExist();

    // Check if already verified
    if (user['email_verified_at'] != null) {
      throw AuthException('Email already verified');
    }

    // Generate verification token
    final token = Hashing()
        .hash('${DateTime.now().millisecondsSinceEpoch}${email}verify');
    final tokenHash = Hashing().hash(token);

    // Store token in database with expiry (24 hours)
    final expiresAt = DateTime.now().add(Duration(hours: 24)).toIso8601String();

    await QueryBuilder(table: 'email_verification_tokens').insert({
      'email': email,
      'token': tokenHash,
      'expires_at': expiresAt,
      'created_at': DateTime.now().toIso8601String(),
    });

    return token;
  }

  static Future<bool> verifyEmail(String token) async {
    await ensureFrameworkTablesExist();

    final tokenHash = Hashing().hash(token);
    final qb = QueryBuilder(table: 'email_verification_tokens');

    final tokenRecord = await qb
        .where('token', '=', tokenHash)
        .where('expires_at', '>', DateTime.now().toIso8601String())
        .first();

    if (tokenRecord == null) {
      return false;
    }

    final email = tokenRecord['email'] as String;

    // Only update email_verified_at if the column exists
    final emailVerifiedAtExists =
        await _columnExists(config.table, 'email_verified_at');
    if (emailVerifiedAtExists) {
      await QueryBuilder(table: config.table)
          .where(config.emailColumn, '=', email)
          .update({
        'email_verified_at': DateTime.now().toIso8601String(),
      });
    }

    await qb.where('token', '=', tokenHash).delete();

    return true;
  }

  /// Check if email is verified
  static Future<bool> isEmailVerified(String email) async {
    final qb = QueryBuilder(table: config.table);
    final user = await qb.where(config.emailColumn, '=', email).first();

    if (user == null) return false;
    return user['email_verified_at'] != null;
  }

  /// Google OAuth - returns user data without saving
  static Future<Map<String, dynamic>> loginWithGoogle({
    String? idToken,
    String? code,
    String? callbackPath,
  }) async {
    return GoogleProvider.authenticate(
      idToken: idToken,
      code: code,
      callbackPath: callbackPath,
      clientId: config.googleClientId,
      clientSecret: config.googleClientSecret,
      redirectBase: config.redirectBase,
    );
  }

  /// Verify Google token - returns user data
  static Future<Map<String, dynamic>> verifyGoogleToken(String idToken) async {
    return GoogleProvider.verifyIdToken(
      idToken,
      clientId: config.googleClientId,
    );
  }

  /// GitHub OAuth - returns user data without saving
  static Future<Map<String, dynamic>> loginWithGitHub({
    required String code,
    String? callbackPath,
  }) async {
    return GitHubProvider.authenticate(
      code: code,
      callbackPath: callbackPath,
      clientId: config.githubClientId,
      clientSecret: config.githubClientSecret,
      redirectBase: config.redirectBase,
    );
  }

  /// Facebook OAuth - returns user data without saving
  static Future<Map<String, dynamic>> loginWithFacebook({
    String? accessToken,
    String? code,
    String? callbackPath,
  }) async {
    return FacebookProvider.authenticate(
      accessToken: accessToken,
      code: code,
      callbackPath: callbackPath,
      clientId: config.facebookClientId,
      clientSecret: config.facebookClientSecret,
      redirectBase: config.redirectBase,
    );
  }

  /// Apple Sign In - returns user data without saving
  static Future<Map<String, dynamic>> loginWithApple({
    required String identityToken,
    String? authorizationCode,
    String? userData,
  }) async {
    return AppleProvider.authenticate(
      identityToken: identityToken,
      authorizationCode: authorizationCode,
      userData: userData,
      clientId: config.appleClientId,
      teamId: config.appleTeamId,
      keyId: config.appleKeyId,
      privateKey: config.applePrivateKey,
    );
  }

  /// Save provider user to database (optional) - returns saved user data
  static Future<Map<String, dynamic>> saveProviderUser({
    required Map<String, dynamic> providerUserData,
    Map<String, dynamic>? additionalData,
  }) async {
    final table = config.table;
    final provider = providerUserData['provider'];
    final providerId = providerUserData['providerId'];
    final email = providerUserData['email'];
    final name = providerUserData['name'];

    // Check if user exists by provider
    var user = await QueryBuilder(table: table)
        .where(config.providerColumn ?? "provider", '=', provider)
        .where(config.providerIdColumn ?? "provider_id", '=', providerId)
        .first();

    if (user != null) {
      // Build safe update data
      final updateData = <String, dynamic>{};

      // Only update email if the column exists
      final emailColumnExists = await _columnExists(table, config.emailColumn);
      if (emailColumnExists) {
        updateData[config.emailColumn] = email;
      }

      // Only update name if the column exists and name is provided
      if (name != null && config.nameColumn != null) {
        final nameColumnExists = await _columnExists(table, config.nameColumn!);
        if (nameColumnExists) {
          updateData[config.nameColumn!] = name;
        }
      }

      // Only update updated_at if the column exists
      final updatedAtExists = await _columnExists(table, 'updated_at');
      if (updatedAtExists) {
        updateData['updated_at'] = DateTime.now().toIso8601String();
      }

      if (updateData.isNotEmpty) {
        await QueryBuilder(table: table)
            .where('id', '=', user['id'])
            .update(updateData);
      }
    } else {
      // Check by email
      user = await QueryBuilder(table: table)
          .where(config.emailColumn, '=', email)
          .first();

      if (user != null) {
        // Update existing user with provider info
        final updateData = <String, dynamic>{};

        // Only update provider columns if they exist
        if (config.providerColumn != null) {
          final providerColumnExists =
              await _columnExists(table, config.providerColumn!);
          if (providerColumnExists) {
            updateData[config.providerColumn!] = provider;
          }
        }

        if (config.providerIdColumn != null) {
          final providerIdColumnExists =
              await _columnExists(table, config.providerIdColumn!);
          if (providerIdColumnExists) {
            updateData[config.providerIdColumn!] = providerId;
          }
        }

        // Only update updated_at if the column exists
        final updatedAtExists = await _columnExists(table, 'updated_at');
        if (updatedAtExists) {
          updateData['updated_at'] = DateTime.now().toIso8601String();
        }

        if (updateData.isNotEmpty) {
          await QueryBuilder(table: table)
              .where('id', '=', user['id'])
              .update(updateData);
        }
      } else {
        // Create new user with safe data
        final data = await _buildSafeUserData(
          email: email,
          hashedPassword: '', // No password for provider users
          name: name,
          additionalData: {
            if (config.providerColumn != null) config.providerColumn!: provider,
            if (config.providerIdColumn != null)
              config.providerIdColumn!: providerId,
            ...?additionalData,
          },
        );

        await QueryBuilder(table: table).insert(data);

        user = await QueryBuilder(table: table)
            .where(config.emailColumn, '=', email)
            .first();
      }
    }

    return _sanitizeUserData(user!);
  }

  /// Generate JWT token from user data
  static String generateToken(Map<String, dynamic> userData) {
    final payload = {
      'id': userData['id'],
      'email': userData[config.emailColumn],
      'name': userData[config.nameColumn],
      'provider': userData[config.providerColumn],
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp': DateTime.now()
              .add(const Duration(hours: 24))
              .millisecondsSinceEpoch ~/
          1000,
    };

    return FlintJwt(config.jwtSecret!).generateToken(payload);
  }

  /// Verify JWT token
  static Map<String, dynamic>? verifyToken(String token) {
    try {
      return FlintJwt(config.jwtSecret!).verifyToken(token);
    } catch (e) {
      return null;
    }
  }

  /// Remove sensitive data from user object
  static Map<String, dynamic> _sanitizeUserData(Map<String, dynamic> user) {
    final sanitized = Map<String, dynamic>.from(user);
    sanitized.remove(config.passwordColumn);
    return sanitized;
  }

  static Future<bool> _columnExists(String tableName, String columnName) async {
    try {
      await DB.execute('SELECT $columnName FROM $tableName LIMIT 0');
      return true;
    } catch (e) {
      final err = e.toString().toLowerCase();

      // MySQL and PostgreSQL error patterns
      if (err.contains('does not exist') ||
          err.contains('no such column') ||
          err.contains('unknown column') || // ✅ MySQL version
          err.contains('42703')) {
        // ✅ PostgreSQL error code
        return false;
      }

      print('⚠️ Could not determine if column $columnName exists: $e');
      return false;
    }
  }

  /// Safely build user data by checking which columns actually exist
  static Future<Map<String, dynamic>> _buildSafeUserData({
    required String email,
    required String hashedPassword,
    String? name,
    Map<String, dynamic>? additionalData,
  }) async {
    final data = <String, dynamic>{};

    // Always include required columns
    data[config.emailColumn] = email;
    data[config.passwordColumn] = hashedPassword;

    // Only include name if the column exists and name is provided
    if (name != null && config.nameColumn != null) {
      final nameColumnExists =
          await _columnExists(config.table, config.nameColumn!);
      if (nameColumnExists) {
        data[config.nameColumn!] = name;
      }
    }

    // Only include created_at if the column exists

    // Only include provider columns if they exist and are provided in additionalData
    if (config.providerColumn != null) {
      final providerColumnExists =
          await _columnExists(config.table, config.providerColumn!);
      if (providerColumnExists &&
          additionalData?[config.providerColumn!] != null) {
        data[config.providerColumn!] = additionalData![config.providerColumn!];
      }
    }

    if (config.providerIdColumn != null) {
      final providerIdColumnExists =
          await _columnExists(config.table, config.providerIdColumn!);
      if (providerIdColumnExists &&
          additionalData?[config.providerIdColumn!] != null) {
        data[config.providerIdColumn!] =
            additionalData![config.providerIdColumn!];
      }
    }

    // Only include email_verified_at if the column exists
    final emailVerifiedAtExists =
        await _columnExists(config.table, 'email_verified_at');
    if (emailVerifiedAtExists && additionalData?['email_verified_at'] != null) {
      data['email_verified_at'] = additionalData!['email_verified_at'];
    }

    // Include any additional data for columns that actually exist
    if (additionalData != null) {
      for (final entry in additionalData.entries) {
        if (entry.key != config.providerColumn &&
            entry.key != config.providerIdColumn &&
            entry.key != 'email_verified_at') {
          final columnExists = await _columnExists(config.table, entry.key);
          if (columnExists) {
            data[entry.key] = entry.value;
          }
        }
      }
    }

    return data;
  }

  static bool _frameworkTablesEnsured = false;

  static Future<void> ensureFrameworkTablesExist() async {
    if (_frameworkTablesEnsured) return;

    try {
      // Only check/create the framework-specific tables
      final passwordResetExists = await _tableExists('password_reset_tokens');
      final emailVerifyExists = await _tableExists('email_verification_tokens');

      if (!passwordResetExists || !emailVerifyExists) {
        print('🔄 Creating framework auth tables...');
        await _createFrameworkTables();
      }

      _frameworkTablesEnsured = true;
    } catch (e) {
      throw AuthException('Framework table setup failed: $e');
    }
  }

  static Future<bool> _tableExists(String tableName) async {
    try {
      await QueryBuilder(table: tableName).limit(1).first();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _createFrameworkTables() async {
    // Only create the framework-specific tables
    final frameworkTables = [
      // Password reset tokens table (framework internal)
      '''
      CREATE TABLE IF NOT EXISTS password_reset_tokens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL,
        token TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
      ''',

      // Email verification tokens table (framework internal)
      '''
      CREATE TABLE IF NOT EXISTS email_verification_tokens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL,
        token TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
      ''',
    ];

    for (final sql in frameworkTables) {
      try {
        await DB.execute(sql);
      } catch (e) {
        print('⚠️ Failed to create framework table: $e');
        rethrow;
      }
    }

    // Create indexes for framework tables
    final frameworkIndexes = [
      'CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_token ON password_reset_tokens(token)',
      'CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_email ON password_reset_tokens(email)',
      'CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_expires ON password_reset_tokens(expires_at)',
      'CREATE INDEX IF NOT EXISTS idx_email_verification_tokens_token ON email_verification_tokens(token)',
      'CREATE INDEX IF NOT EXISTS idx_email_verification_tokens_email ON email_verification_tokens(email)',
    ];

    for (final sql in frameworkIndexes) {
      try {
        await DB.execute(sql);
      } catch (e) {
        print('⚠️ Failed to create framework index: $e');
      }
    }

    print('✅ Framework auth tables created successfully');
  }

  static Future<void> ensureMigrationsRun() async {}
}
