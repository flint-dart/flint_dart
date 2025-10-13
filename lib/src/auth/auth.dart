// auth.dart
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
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

    // Prepare data
    final data = {
      config.emailColumn: email,
      config.passwordColumn: hashedPassword,
      if (name != null && config.nameColumn != null) config.nameColumn!: name,
      'created_at': DateTime.now().toIso8601String(),
      if (additionalData != null) ...additionalData,
    };

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
      // Update existing user
      await QueryBuilder(table: table).where('id', '=', user['id']).update({
        config.emailColumn: email,
        config.nameColumn!: name,
      });
    } else {
      // Check by email
      user = await QueryBuilder(table: table)
          .where(config.emailColumn, '=', email)
          .first();

      if (user != null) {
        // Update existing user with provider info
        await QueryBuilder(table: table).where('id', '=', user['id']).update({
          config.providerColumn!: provider,
          config.providerIdColumn!: providerId,
        });
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
}
