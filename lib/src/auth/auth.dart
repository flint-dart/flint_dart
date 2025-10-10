// auth.dart
import 'package:flint_dart/db.dart';
import 'package:flint_dart/security.dart';
import 'package:flint_dart/src/auth/auth_config.dart';
import 'package:flint_dart/src/auth/providers/google_provider.dart';
import 'package:flint_dart/src/auth/providers/github_provider.dart';
import 'package:flint_dart/src/auth/providers/facebook_provider.dart';
import 'package:flint_dart/src/auth/providers/apple_provider.dart';
import 'package:flint_dart/src/database/db.dart';
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
    );
  }

  /// Email/password login - returns user data
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final db = DB.instance;

    final rows = await db.query(
      'SELECT * FROM `${config.table}` WHERE `${config.emailColumn}` = ? LIMIT 1',
      positionalParams: [email],
    );

    if (rows.isEmpty) {
      throw AuthException('Invalid email or password');
    }

    final user = rows.first;
    final hashedPassword = user[config.passwordColumn] as String;
    final isMatch = Hashing().verify(password, hashedPassword);

    if (!isMatch) {
      throw AuthException('Invalid email or password');
    }

    return _sanitizeUserData(user);
  }

  /// Register new user - returns user data
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? name,
    Map<String, dynamic>? additionalData,
  }) async {
    final db = DB.instance;

    // Check if user exists
    final existing = await db.query(
      'SELECT id FROM `${config.table}` WHERE `${config.emailColumn}` = ?',
      positionalParams: [email],
    );

    if (existing.isNotEmpty) {
      throw AuthException('User already exists with this email');
    }

    // Hash password
    final hashedPassword = Hashing().hash(password);

    // Prepare data
    final data = {
      config.emailColumn: email,
      config.passwordColumn: hashedPassword,
      if (name != null && config.nameColumn != null) config.nameColumn!: name,
      'created_at': DateTime.now().toIso8601String(),
      if (additionalData != null) ...additionalData,
    };

    // Insert user
    final columns = data.keys.join(', ');
    final placeholders = List.filled(data.length, '?').join(', ');
    final values = data.values.toList();

    final result = await db.query(
      'INSERT INTO `${config.table}` ($columns) VALUES ($placeholders)',
      positionalParams: values,
    );

    // Get created user
    final userId = result.first["id"];
    final userRows = await db.query(
      'SELECT * FROM `${config.table}` WHERE id = ?',
      positionalParams: [userId],
    );

    return _sanitizeUserData(userRows.first);
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
    final db = DB.instance;
    final provider = providerUserData['provider'];
    final providerId = providerUserData['providerId'];
    final email = providerUserData['email'];
    final name = providerUserData['name'];

    // Check if user exists by provider
    var rows = await db.query(
      'SELECT * FROM `${config.table}` WHERE `${config.providerColumn}` = ? AND `${config.providerIdColumn}` = ?',
      positionalParams: [provider, providerId],
    );

    Map<String, dynamic> user;

    if (rows.isNotEmpty) {
      // Update existing user
      user = rows.first;
      final userId = user['id'];

      await db.execute(
        'UPDATE `${config.table}` SET `${config.emailColumn}` = ?, `${config.nameColumn}` = ? WHERE id = ?',
        positionalParams: [email, name, userId],
      );
    } else {
      // Check by email
      rows = await db.query(
        'SELECT * FROM `${config.table}` WHERE `${config.emailColumn}` = ?',
        positionalParams: [email],
      );

      if (rows.isNotEmpty) {
        // Update existing user with provider info
        user = rows.first;
        final userId = user['id'];

        await db.execute(
          'UPDATE `${config.table}` SET `${config.providerColumn}` = ?, `${config.providerIdColumn}` = ? WHERE id = ?',
          positionalParams: [provider, providerId, userId],
        );
      } else {
        // Create new user
        final data = {
          config.emailColumn: email,
          config.nameColumn!: name,
          config.providerColumn!: provider,
          config.providerIdColumn!: providerId,
          'created_at': DateTime.now().toIso8601String(),
          if (additionalData != null) ...additionalData,
        };

        final columns = data.keys.join(', ');
        final placeholders = List.filled(data.length, '?').join(', ');
        final values = data.values.toList();

        final result = await db.query(
          'INSERT INTO `${config.table}` ($columns) VALUES ($placeholders)',
          positionalParams: values,
        );

        final userId = result.first["id"];
        rows = await db.query(
          'SELECT * FROM `${config.table}` WHERE id = ?',
          positionalParams: [userId],
        );
        user = rows.first;
      }
    }

    return _sanitizeUserData(user);
  }

  /// Generate JWT token from user data
  static String generateToken(Map<String, dynamic> userData) {
    final payload = {
      'id': userData['id'],
      'email': userData[config.emailColumn],
      'name': userData[config.nameColumn],
      'provider': userData[config.providerColumn],
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp': DateTime.now().add(Duration(hours: 24)).millisecondsSinceEpoch ~/
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
}
