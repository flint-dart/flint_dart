// auth.dart
import 'dart:convert';
import 'dart:io';

import 'package:flint_dart/db.dart';
import 'package:flint_dart/security.dart';
import 'package:flint_dart/src/auth/auth_config.dart';
import 'package:flint_dart/src/env_parser.dart';
import 'package:flint_dart/src/validation/validator.dart';

class Auth {
  static final AuthConfig _config = _loadConfig();

  static AuthConfig get config => _config;

  static AuthConfig _loadConfig() {
    final table = FlintEnv.get('AUTH_TABLE', '');
    final emailColumn = FlintEnv.get('AUTH_EMAIL_COLUMN', '');
    final passwordColumn = FlintEnv.get('AUTH_PASSWORD_COLUMN', '');
    final googleClientId = FlintEnv.get('GOOGLE_CLIENT_ID', '');
    final googleClientSecret = FlintEnv.get('GOOGLE_CLIENT_SECRET', '');
    final redirectBase = FlintEnv.get('REDIRECT_BASE', 'http://localhost:3000');

    if (table.isEmpty || emailColumn.isEmpty || passwordColumn.isEmpty) {
      throw Exception(
          'Missing auth configuration. Ensure AUTH_TABLE, AUTH_EMAIL_COLUMN, and AUTH_PASSWORD_COLUMN are set.');
    }

    return AuthConfig(
      table: table,
      emailColumn: emailColumn,
      passwordColumn: passwordColumn,
      googleClientId: googleClientId,
      googleClientSecret: googleClientSecret,
      redirectBase: redirectBase,
    );
  }

  /// Email/password login
  static Future<String> login(String email, String password) async {
    final db = DB.instance;

    final rows = await db.query(
      'SELECT * FROM `${config.table}` WHERE `${config.emailColumn}` = ? LIMIT 1',
      positionalParams: [email],
    );

    if (rows.isEmpty) {
      throw ValidationException({
        'password': ['Invalid email or password.']
      });
    }

    final user = rows.first;
    final hashedPassword = user[config.passwordColumn] as String;
    final isMatch = Hashing().verify(password, hashedPassword);

    if (!isMatch) {
      throw ValidationException({
        'password': ['Invalid email or password.']
      });
    }

    final token = FlintJwt("sdf").generateToken({
      'id': user['id'],
      'email': user[config.emailColumn],
    });

    return token;
  }

  /// Google OAuth login
  static Future<Map<String, dynamic>> loginWithGoogle({
    String? idToken,
    String? code,
    String? callbackPath,
  }) async {
    if (idToken == null && code == null) {
      throw ArgumentError('Either idToken or code must be provided.');
    }

    final googleClientId = config.googleClientId;
    final googleClientSecret = config.googleClientSecret;
    final redirectBase = config.redirectBase;

    if (googleClientId == null || googleClientSecret!.isEmpty) {
      throw Exception(
          'Google Auth is not configured. Ensure GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET are set.');
    }

    Map<String, dynamic> profile;

    if (idToken != null) {
      profile = await _verifyGoogleIdToken(idToken);
    } else {
      if (callbackPath == null) {
        throw ArgumentError('callbackPath is required when exchanging code.');
      }
      final tokenResp = await _exchangeCodeForToken(
        code!,
        googleClientId,
        googleClientSecret,
        '$redirectBase$callbackPath',
      );
      final accessToken = tokenResp['access_token'] as String?;
      final idTokenFromGoogle = tokenResp['id_token'] as String?;
      if (idTokenFromGoogle != null) {
        profile = await _verifyGoogleIdToken(idTokenFromGoogle);
      } else if (accessToken != null) {
        profile = await _fetchGoogleProfile(accessToken);
      } else {
        throw Exception(
            'Could not obtain access_token or id_token from Google.');
      }
    }

    await _ensureProviderColumns();

    final provider = 'google';
    final providerId = profile['sub']?.toString() ?? profile['id']?.toString();
    final email = profile['email']?.toString();
    final name =
        profile['name']?.toString() ?? profile['given_name']?.toString();

    if (providerId == null) {
      throw Exception('Could not determine Google provider id from profile.');
    }

    final db = DB.instance;
    final cfg = config;

    // 1) Find by provider + providerId
    var rows = await db.query(
      'SELECT * FROM `${cfg.table}` WHERE `${cfg.providerColumn}` = ? AND `${cfg.providerIdColumn}` = ? LIMIT 1',
      positionalParams: [provider, providerId],
    );

    int userId;
    Map<String, dynamic> userRow;

    if (rows.isNotEmpty) {
      userRow = rows.first;
      userId = userRow['id'] as int;
      await db.execute(
        'UPDATE `${cfg.table}` SET `${cfg.nameColumn}` = ?, `${cfg.emailColumn}` = ? WHERE id = ?',
        positionalParams: [name, email, userId],
      );
    } else if (email != null) {
      // 2) Find by email
      rows = await db.query(
        'SELECT * FROM `${cfg.table}` WHERE `${cfg.emailColumn}` = ? LIMIT 1',
        positionalParams: [email],
      );
      if (rows.isNotEmpty) {
        userRow = rows.first;
        userId = userRow['id'] as int;
        await db.execute(
          'UPDATE `${cfg.table}` SET `${cfg.providerColumn}` = ?, `${cfg.providerIdColumn}` = ? WHERE id = ?',
          positionalParams: [provider, providerId, userId],
        );
      } else {
        // 3) Create new user
        var inserted = await db.query(
          'INSERT INTO `${cfg.table}` (`${cfg.emailColumn}`, `${cfg.nameColumn}`, `${cfg.providerColumn}`, `${cfg.providerIdColumn}`, created_at) VALUES (?, ?, ?, ?, NOW())',
          positionalParams: [email, name, provider, providerId],
        );
        userId = await inserted.firstOrNull?['id'];
        rows = await db.query(
          'SELECT * FROM `${cfg.table}` WHERE id = ? LIMIT 1',
          positionalParams: [userId],
        );
        userRow = rows.first;
      }
    } else {
      // No email: create user with provider only
      var user = await db.query(
        'INSERT INTO `${cfg.table}` (`${cfg.nameColumn}`, `${cfg.providerColumn}`, `${cfg.providerIdColumn}`, created_at) VALUES (?, ?, ?, NOW())',
        positionalParams: [name, provider, providerId],
      );
      userId = user.single['id'];
      rows = await db.query(
        'SELECT * FROM `${cfg.table}` WHERE id = ? LIMIT 1',
        positionalParams: [userId],
      );
      userRow = rows.first;
    }

    final token = FlintJwt("sdf").generateToken({
      'id': userRow['id'],
      'email': userRow[cfg.emailColumn],
      'provider': provider,
    });

    return {'token': token, 'user': userRow};
  }

  static Future<void> _ensureProviderColumns() async {
    // final db = DB.instance;
    // final cfg = config;
    // if (cfg.providerColumn != null && !columns.contains(cfg.providerColumn)) {
    //   await db.execute(
    //       'ALTER TABLE ${cfg.table} ADD COLUMN ${cfg.providerColumn} VARCHAR(50) NULL');
    // }

    // if (cfg.providerIdColumn != null &&
    //     !columns.contains(cfg.providerIdColumn)) {
    //   await db.execute(
    //       'ALTER TABLE ${cfg.table} ADD COLUMN ${cfg.providerIdColumn} VARCHAR(255) NULL');
    // }
  }

  // ---------- Google helpers ----------

  static Future<Map<String, dynamic>> _verifyGoogleIdToken(
      String idToken) async {
    final uri =
        Uri.https('oauth2.googleapis.com', '/tokeninfo', {'id_token': idToken});
    final client = HttpClient();
    final req = await client.getUrl(uri);
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    client.close();

    if (resp.statusCode != 200) {
      throw Exception('Invalid Google id_token: ${resp.statusCode} $body');
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _exchangeCodeForToken(
    String code,
    String clientId,
    String clientSecret,
    String redirectUri,
  ) async {
    final uri = Uri.https('oauth2.googleapis.com', '/token');
    final client = HttpClient();
    final req = await client.postUrl(uri);
    req.headers.contentType =
        ContentType('application', 'x-www-form-urlencoded');

    final body = {
      'code': code,
      'client_id': clientId,
      'client_secret': clientSecret,
      'redirect_uri': redirectUri,
      'grant_type': 'authorization_code',
    };
    req.write(Uri(queryParameters: body).query);

    final resp = await req.close();
    final s = await resp.transform(utf8.decoder).join();
    client.close();

    if (resp.statusCode != 200) {
      throw Exception('Failed to exchange code: ${resp.statusCode} $s');
    }
    return jsonDecode(s) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _fetchGoogleProfile(
      String accessToken) async {
    final uri = Uri.https('www.googleapis.com', '/oauth2/v2/userinfo');
    final client = HttpClient();
    final req = await client.getUrl(uri);
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
    final resp = await req.close();
    final s = await resp.transform(utf8.decoder).join();
    client.close();

    if (resp.statusCode != 200) {
      throw Exception('Failed to fetch Google profile: ${resp.statusCode} $s');
    }
    return jsonDecode(s) as Map<String, dynamic>;
  }
}
