// auth.dart
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flint_dart/db.dart';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/security.dart';
import 'package:flint_dart/src/auth/auth_config.dart';
import 'package:flint_dart/src/auth/providers/google_provider.dart';
import 'package:flint_dart/src/auth/providers/github_provider.dart';
import 'package:flint_dart/src/auth/providers/facebook_provider.dart';
import 'package:flint_dart/src/auth/providers/apple_provider.dart';
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
      throw AuthException(message: 'Invalid email or password');
    }

    final hashedPassword = user[_config.passwordColumn] as String;
    final isMatch = Hashing().verify(password, hashedPassword);

    if (!isMatch) {
      throw AuthException(message: 'Invalid email or password');
    }

    if (_config.requireEmailVerification && user['email_verified_at'] == null) {
      throw AuthException(message: 'Email verification required.');
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
      throw AuthException(message: 'User already exists with this email');
    }

    if (password.length < _config.passwordMinLength) {
      throw AuthException(
        message:
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
      throw AuthException(
          message: 'User could not be retrieved after registration.');
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
        message:
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
      throw AuthException(message: 'Email already verified');
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
        await columnExists(config.table, 'email_verified_at');
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
    List<String>? conflictProviders, // optional
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

    if (user != null &&
        conflictProviders != null &&
        conflictProviders.contains(user[config.providerColumn ?? 'provider'])) {
      throw Exception('User already registered with a different provider');
    }

    if (user != null) {
      // Build safe update data
      final updateData = <String, dynamic>{};

      // Only update email if the column exists
      final emailColumnExists = await columnExists(table, config.emailColumn);
      if (emailColumnExists) {
        updateData[config.emailColumn] = email;
      }

      // Only update name if the column exists and name is provided
      if (name != null && config.nameColumn != null) {
        final nameColumnExists = await columnExists(table, config.nameColumn!);
        if (nameColumnExists) {
          updateData[config.nameColumn!] = name;
        }
      }

      // Only update updated_at if the column exists
      final updatedAtExists = await columnExists(table, 'updated_at');
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
              await columnExists(table, config.providerColumn!);
          if (providerColumnExists) {
            updateData[config.providerColumn!] = provider;
          }
        }

        if (config.providerIdColumn != null) {
          final providerIdColumnExists =
              await columnExists(table, config.providerIdColumn!);
          if (providerIdColumnExists) {
            updateData[config.providerIdColumn!] = providerId;
          }
        }

        // Only update updated_at if the column exists
        final updatedAtExists = await columnExists(table, 'updated_at');
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
    return FlintJwt(config.jwtSecret!).generateToken(userData);
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

  static Future<bool> columnExists(String tableName, String columnName) async {
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

      Log.debug('⚠️ Could not determine if column $columnName exists: $e');
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
          await columnExists(config.table, config.nameColumn!);
      if (nameColumnExists) {
        data[config.nameColumn!] = name;
      }
    }

    // Only include created_at if the column exists

    // Only include provider columns if they exist and are provided in additionalData
    if (config.providerColumn != null) {
      final providerColumnExists =
          await columnExists(config.table, config.providerColumn!);
      if (providerColumnExists &&
          additionalData?[config.providerColumn!] != null) {
        data[config.providerColumn!] = additionalData![config.providerColumn!];
      }
    }

    if (config.providerIdColumn != null) {
      final providerIdColumnExists =
          await columnExists(config.table, config.providerIdColumn!);
      if (providerIdColumnExists &&
          additionalData?[config.providerIdColumn!] != null) {
        data[config.providerIdColumn!] =
            additionalData![config.providerIdColumn!];
      }
    }

    // Only include email_verified_at if the column exists
    final emailVerifiedAtExists =
        await columnExists(config.table, 'email_verified_at');
    if (emailVerifiedAtExists && additionalData?['email_verified_at'] != null) {
      data['email_verified_at'] = additionalData!['email_verified_at'];
    }

    // Include any additional data for columns that actually exist
    if (additionalData != null) {
      for (final entry in additionalData.entries) {
        if (entry.key != config.providerColumn &&
            entry.key != config.providerIdColumn &&
            entry.key != 'email_verified_at') {
          final columnExist = await columnExists(config.table, entry.key);
          if (columnExist) {
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
      final passwordResetExists = await DB.tableExists('password_reset_tokens');
      final emailVerifyExists =
          await DB.tableExists('email_verification_tokens');

      if (!passwordResetExists || !emailVerifyExists) {
        Log.debug('🔄 Creating framework auth tables...');
        await _createFrameworkTables();
      }

      _frameworkTablesEnsured = true;
    } catch (e) {
      throw AuthException(message: 'Framework table setup failed: $e');
    }
  }

  static Future<void> _createFrameworkTables() async {
    final dbType =
        DB.driver; // e.g. DBDriver.mysql, DBDriver.postgres, DBDriver.sqlite

    String idColumn;
    String textType;

    // Define ID and text column types based on DB driver
    if (dbType == DBDriver.mysql) {
      idColumn = 'id INT PRIMARY KEY AUTO_INCREMENT';
      textType = 'VARCHAR(255)';
    } else if (dbType == DBDriver.postgres) {
      idColumn = 'id SERIAL PRIMARY KEY';
      textType = 'TEXT';
    } else {
      idColumn = 'id INTEGER PRIMARY KEY AUTOINCREMENT';
      textType = 'TEXT';
    }

    final frameworkTables = [
      '''
    CREATE TABLE IF NOT EXISTS password_reset_tokens (
      $idColumn,
      email $textType NOT NULL,
      token $textType NOT NULL,
      expires_at $textType NOT NULL,
      created_at $textType NOT NULL
    )
    ''',
      '''
    CREATE TABLE IF NOT EXISTS email_verification_tokens (
      $idColumn,
      email $textType NOT NULL,
      token $textType NOT NULL,
      expires_at $textType NOT NULL,
      created_at $textType NOT NULL
    )
    '''
    ];

    // Create tables
    for (final sql in frameworkTables) {
      try {
        await DB.execute(sql);
      } catch (e, stack) {
        Log.warning('⚠️ Failed to create framework table: ',
            error: e, stackTrace: stack);
        rethrow;
      }
    }

    // Create indexes
    final indexes = [
      ('password_reset_tokens', 'token'),
      ('password_reset_tokens', 'email'),
      ('password_reset_tokens', 'expires_at'),
      ('email_verification_tokens', 'token'),
      ('email_verification_tokens', 'email'),
    ];

    for (final (table, column) in indexes) {
      final indexName = 'idx_${table}_$column';

      try {
        if (dbType == DBDriver.postgres) {
          await DB.execute(
              'CREATE INDEX IF NOT EXISTS $indexName ON $table($column)');
        } else if (dbType == DBDriver.mysql) {
          // MySQL requires manual check and key length
          final check = await DB.query(
            "SHOW INDEX FROM $table WHERE Key_name = '$indexName'",
          );
          if (check.isEmpty) {
            await DB.execute(
                'CREATE INDEX $indexName ON $table($column(255))'); // note the (255)
          }
        }
      } catch (e, stack) {
        Log.error('⚠️ Failed to create framework index: ',
            error: e, stackTrace: stack);
      }
    }

    Log.debug('✅ Framework auth tables created successfully');
  }

  static Future<void> ensureMigrationsRun() async {}

  /// Generate numeric verification code (like OTP)
  static Future<String> generateNumericVerificationCode(
    String email, {
    int length = 6,
  }) async {
    await Auth.ensureFrameworkTablesExist();

    // Check if the user exists
    final user = await QueryBuilder(table: Auth.config.table)
        .where(Auth.config.emailColumn, '=', email)
        .first();
    if (user == null) {
      throw AuthException(message: 'No account found for this email.');
    }

    // Generate numeric code
    final rng = Random();
    final code = List.generate(length, (_) => rng.nextInt(10)).join('');
    // Hash code before storing

    // Expire after 10 minutes
    final expiresAt =
        DateTime.now().add(Duration(minutes: 10)).toIso8601String();
    final codeHash = Hashing().hash(code);

    // 🧹 Delete any previous unused codes for this email
    await QueryBuilder(table: 'email_verification_tokens')
        .where('email', '=', email)
        .delete();

    // Store new verification code
    await QueryBuilder(table: 'email_verification_tokens').insert({
      'email': email,
      'token': codeHash,
      'expires_at': expiresAt,
      'created_at': DateTime.now().toIso8601String(),
    });

    Log.debug('📨 Verification code generated for $email');

    return code; // ⚠️ Return plain code to send via mail or SMS
  }

  /// Verify numeric verification code
  static Future<bool> verifyNumericCode(String email, String code) async {
    await Auth.ensureFrameworkTablesExist();

    // Find matching valid record
    final record = await QueryBuilder(table: 'email_verification_tokens')
        .where('email', '=', email)
        .where('expires_at', '>', DateTime.now().toIso8601String())
        .first();

    if (record == null) {
      Log.warning('❌ Invalid or expired verification code for $email');
      return false;
    }

    final isValid = Hashing().verify(code, record['token']);

    if (!isValid) {
      Log.warning('❌ Invalid verification code for $email');
      return false;
    }
    // Mark email as verified
    final emailVerifiedAtExists =
        await Auth.columnExists(Auth.config.table, 'email_verified_at');
    if (emailVerifiedAtExists) {
      await QueryBuilder(table: Auth.config.table)
          .where(Auth.config.emailColumn, '=', email)
          .update({
        'email_verified_at': DateTime.now().toIso8601String(),
      });
    }

    // 🧹 Delete used code
    await QueryBuilder(table: 'email_verification_tokens')
        .where('email', '=', email)
        .delete();

    Log.debug('✅ Email verified successfully: $email');
    return true;
  }

  /// Optional helper: resend new OTP after deleting the old one
  static Future<String> resendVerificationCode(String email) async {
    await QueryBuilder(table: 'email_verification_tokens')
        .where('email', '=', email)
        .delete();
    return generateNumericVerificationCode(email);
  }

  /// Generate numeric password reset code (OTP-style)
  static Future<String> generatePasswordResetCode(
    String email, {
    int length = 6,
  }) async {
    await Auth.ensureFrameworkTablesExist();

    // Check if user exists
    final user = await QueryBuilder(table: Auth.config.table)
        .where(Auth.config.emailColumn, '=', email)
        .first();
    if (user == null) {
      throw AuthException(message: 'No account found for this email.');
    }

    // Generate numeric OTP code
    final rng = Random();
    final code = List.generate(length, (_) => rng.nextInt(10)).join('');

    // Hash OTP before storing
    final codeHash = Hashing().hash(code);

    // Expire after 15 minutes
    final expiresAt =
        DateTime.now().add(Duration(minutes: 15)).toIso8601String();

    // 🧹 Remove any previous codes for this email
    await QueryBuilder(table: 'password_reset_tokens')
        .where('email', '=', email)
        .delete();

    // Store the new code
    await QueryBuilder(table: 'password_reset_tokens').insert({
      'email': email,
      'token': codeHash,
      'expires_at': expiresAt,
      'created_at': DateTime.now().toIso8601String(),
    });

    Log.debug('📨 Password reset code generated for $email');

    return code; // ⚠️ Return plain code to send via email/SMS
  }

  /// Verify reset code and change password
  static Future<bool> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await Auth.ensureFrameworkTablesExist();

    if (newPassword.length < Auth.config.passwordMinLength) {
      throw AuthException(
          message:
              'Password must be at least ${Auth.config.passwordMinLength} characters.');
    }

    // Look for valid code
    final record = await QueryBuilder(table: 'password_reset_tokens')
        .where('email', '=', email)
        .where('expires_at', '>', DateTime.now().toIso8601String())
        .first();

    if (record == null) {
      Log.debug('❌ Invalid or expired password reset code for $email');
      throw AuthException(message: 'Invalid or expired reset code.');
    }
    final isValid = Hashing().verify(code, record['token']);

    if (!isValid) {
      Log.warning('❌ Invalid verification code for $email');
      return false;
    }
    // Hash new password
    final newHashedPassword = Hashing().hash(newPassword);

    // Update user password
    await QueryBuilder(table: Auth.config.table)
        .where(Auth.config.emailColumn, '=', email)
        .update({
      Auth.config.passwordColumn: newHashedPassword,
      'updated_at': DateTime.now().toIso8601String(),
    });

    // 🧹 Remove used reset token
    await QueryBuilder(table: 'password_reset_tokens')
        .where('email', '=', email)
        .delete();

    Log.debug('✅ Password successfully reset for $email');
    return true;
  }

  /// Optional: resend password reset code
  static Future<String> resendPasswordResetCode(String email) async {
    await QueryBuilder(table: 'password_reset_tokens')
        .where('email', '=', email)
        .delete();
    return generatePasswordResetCode(email);
  }

  static String providerRedirectUrl({
    required String provider, // now just a string
    required String redirectPath,
    String? state,
  }) {
    switch (provider.toLowerCase()) {
      case 'github':
        final url = Uri.https('github.com', '/login/oauth/authorize', {
          'client_id': config.githubClientId,
          'redirect_uri': '${config.redirectBase}$redirectPath',
          'scope': 'user:email',
          'allow_signup': 'true',
          if (state != null) 'state': state,
        });
        return url.toString();

      case 'google':
        final url = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
          'client_id': config.googleClientId,
          'redirect_uri': '${config.redirectBase}$redirectPath',
          'response_type': 'code',
          'scope': 'openid email profile',
          if (state != null) 'state': state,
        });
        return url.toString();

      default:
        throw UnimplementedError('Provider "$provider" not implemented');
    }
  }
}

class TotpService {
  static const int _defaultDigits = 6;
  static const int _timeStepSeconds = 30;
  static const String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  static String generateSecret({int length = 20}) {
    final rand = Random.secure();
    final bytes = List<int>.generate(length, (_) => rand.nextInt(256));
    return _base32Encode(Uint8List.fromList(bytes));
  }

  static String buildOtpAuthUrl({
    required String secret,
    required String email,
    String issuer = 'EucloudHost',
  }) {
    final encIssuer = Uri.encodeComponent(issuer);
    final label = Uri.encodeComponent('$issuer:$email');
    return 'otpauth://totp/$label?secret=$secret&issuer=$encIssuer&digits=$_defaultDigits&period=$_timeStepSeconds';
  }

  static bool verifyCode({
    required String secret,
    required String code,
    int window = 1,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final timeCounter = now ~/ _timeStepSeconds;
    for (var i = -window; i <= window; i++) {
      final otp = _hotp(secret, timeCounter + i);
      if (otp == code) return true;
    }
    return false;
  }

  static String _hotp(String secret, int counter) {
    final key = _base32Decode(secret);
    final counterBytes = Uint8List(8);
    final bd = ByteData.view(counterBytes.buffer);
    bd.setInt64(0, counter, Endian.big);

    final hmac = Hmac(sha1, key);
    final digest = hmac.convert(counterBytes).bytes;

    final offset = digest.last & 0x0f;
    final binary = ((digest[offset] & 0x7f) << 24) |
        ((digest[offset + 1] & 0xff) << 16) |
        ((digest[offset + 2] & 0xff) << 8) |
        (digest[offset + 3] & 0xff);

    final otp = binary % pow(10, _defaultDigits) as int;
    return otp.toString().padLeft(_defaultDigits, '0');
  }

  static String _base32Encode(Uint8List data) {
    final output = StringBuffer();
    int buffer = 0;
    int bitsLeft = 0;

    for (final byte in data) {
      buffer = (buffer << 8) | byte;
      bitsLeft += 8;
      while (bitsLeft >= 5) {
        final index = (buffer >> (bitsLeft - 5)) & 0x1f;
        bitsLeft -= 5;
        output.write(_alphabet[index]);
      }
    }

    if (bitsLeft > 0) {
      final index = (buffer << (5 - bitsLeft)) & 0x1f;
      output.write(_alphabet[index]);
    }

    return output.toString();
  }

  static Uint8List _base32Decode(String input) {
    final cleaned = input.replaceAll('=', '').toUpperCase();
    int buffer = 0;
    int bitsLeft = 0;
    final out = <int>[];

    for (final ch in cleaned.split('')) {
      final index = _alphabet.indexOf(ch);
      if (index < 0) continue;
      buffer = (buffer << 5) | index;
      bitsLeft += 5;
      if (bitsLeft >= 8) {
        bitsLeft -= 8;
        final byte = (buffer >> bitsLeft) & 0xff;
        out.add(byte);
      }
    }

    return Uint8List.fromList(out);
  }
}
