// auth.dart
import 'dart:convert';
import 'dart:io';

import 'package:flint_dart/security.dart';
import 'package:flint_dart/src/auth/auth_config.dart';
import 'package:flint_dart/src/database/connection.dart';
import 'package:flint_dart/src/database/db_utils.dart';
import 'package:flint_dart/src/env_parser.dart';
import 'package:flint_dart/src/validation/validator.dart';

/// The central hub for user authentication.
///
/// This class handles all authentication-related logic, including
/// traditional email/password login and social logins like Google. It
/// is designed to be self-configuring by loading all necessary settings
/// from the application's environment variables.
class Auth {
  /// A private static field that holds the loaded authentication configuration.
  /// The configuration is loaded once when the class is first accessed.
  static final AuthConfig _config = _loadConfig();

  /// Loads authentication configuration details from environment variables.
  ///
  /// This method reads keys like `AUTH_TABLE` and `GOOGLE_CLIENT_ID`
  /// and throws an [Exception] if critical settings are missing.
  static AuthConfig _loadConfig() {
    final table = FlintEnv.get('AUTH_TABLE', '');
    final emailColumn = FlintEnv.get('AUTH_EMAIL_COLUMN', "");
    final passwordColumn = FlintEnv.get('AUTH_PASSWORD_COLUMN', "");
    final googleClientId = FlintEnv.get('GOOGLE_CLIENT_ID', "");
    final googleClientSecret = FlintEnv.get('GOOGLE_CLIENT_SECRET', "");
    final redirectBase = FlintEnv.get('REDIRECT_BASE', 'http://localhost:3000');

    if (table.isEmpty || emailColumn.isEmpty || passwordColumn.isEmpty) {
      throw Exception(
          'Missing auth configuration. Ensure AUTH_TABLE, AUTH_EMAIL_COLUMN, and AUTH_PASSWORD_COLUMN are set in your environment.');
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

  /// Get the authentication configuration, which is loaded from the environment.
  static AuthConfig get config => _config;

  /// Authenticates a user with an email and password.
  ///
  /// The method performs the following steps:
  /// 1. Queries the database for a user with the provided email.
  /// 2. Verifies the user's password against the stored hash.
  /// 3. Generates a secure JWT token upon successful authentication.
  ///
  /// Throws a [ValidationException] with a generic "Invalid email or password"
  /// message if authentication fails, preventing attackers from knowing
  /// whether an email exists in the database.
  ///
  /// @param emailColumn The {config.table}'s address.
  /// @param password The user's plain-text password.
  /// @returns A [Future] that completes with a JWT token string.
  static Future<String> login(String email, String password) async {
    final conn = DB.instance;

    // 1. Check if user exists
    final pre = await conn.prepare(
      'SELECT * FROM `${config.table}` WHERE `${config.emailColumn}` = ? LIMIT 1',
    );

    final result = await pre.execute(
      [email],
    );

    if (result.rows.isEmpty) {
      throw ValidationException({
        "password": ["Invalid email or password."]
      });
    }

    final user = result.rows.first.assoc();

    // 2. Verify password
    final hashedPassword = user[config.passwordColumn] as String;
    final isMatch = Hashing().verify(password, hashedPassword);
    if (!isMatch) {
      throw ValidationException({
        "password": ["Invalid email or password."]
      });
    }

    // 3. Generate JWT token
    final token = FlintJwt("sdf").generateToken({
      'id': user['id'],
      'email': user[config.emailColumn],
    });

    return token;
  }

  /// Handles user authentication using Google's OAuth service.
  ///
  /// This method supports two primary flows:
  /// - **ID Token Flow**: The client sends a Google-provided `idToken`, which is verified
  ///   by the server.
  /// - **Authorization Code Flow**: The client sends a `code`, which the server
  ///   exchanges for an access token to retrieve user profile data.
  ///
  /// The method manages user data in the database by either finding an existing
  /// user, linking a new provider to an existing account, or creating a new user.
  ///
  /// Throws an [ArgumentError] if required parameters are missing or an
  /// [Exception] if the authentication process fails.
  ///
  /// @param idToken The ID token from the client (for the frontend flow).
  /// @param code The authorization code from the client (for the server flow).
  /// @param callbackPath The redirect path required for the code flow.
  /// @returns A [Future] that completes with a map containing the JWT token and user data.
  static Future<Map<String, dynamic>> loginWithGoogle({
    String? idToken,
    String? code,
    String? callbackPath, // required when using code flow
  }) async {
    if (idToken == null && code == null) {
      throw ArgumentError('Either idToken or code must be provided.');
    }

    final googleClientId = config.googleClientId;
    final googleClientSecret = config.googleClientSecret;
    final redirectBase = config.redirectBase;

    if (googleClientId == null || googleClientSecret == null) {
      throw Exception(
          'Google Auth is not configured. Ensure GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET are set.');
    }

    Map<String, dynamic> profile;

    if (idToken != null) {
      // Verify id_token using Google's token info endpoint
      profile = await _verifyGoogleIdToken(idToken);
    } else {
      // code flow: exchange authorization code for tokens, then fetch profile
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

    // Upsert user into configured table
    final conn = DB.instance;
    final cfg = config;

    // 1) Try find by provider+provider_id
    final byProvider = await _dbQuery(
      conn,
      'SELECT * FROM `${cfg.table}` WHERE `${cfg.providerColumn}` = ? AND `${cfg.providerIdColumn}` = ? LIMIT 1',
      [provider, providerId],
    );

    int userId;
    Map<String, dynamic>? userRow;

    if (byProvider.isNotEmpty) {
      userRow = byProvider.first;
      userId = userRow['id'] as int;
      // Optionally update name/email
      await _dbExecute(
        conn,
        'UPDATE `${cfg.table}` SET `${cfg.nameColumn}` = ?, `${cfg.emailColumn}` = ? WHERE id = ?',
        [name, email, userId],
      );
    } else {
      // 2) Try find by email (user may have registered with email previously)
      if (email != null) {
        final byEmail = await _dbQuery(
          conn,
          'SELECT * FROM `${cfg.table}` WHERE `${cfg.emailColumn}` = ? LIMIT 1',
          [email],
        );

        if (byEmail.isNotEmpty) {
          userRow = byEmail.first;
          userId = userRow['id'] as int;
          // Link provider
          await _dbExecute(
            conn,
            'UPDATE `${cfg.table}` SET `${cfg.providerColumn}` = ?, `${cfg.providerIdColumn}` = ? WHERE id = ?',
            [provider, providerId, userId],
          );
        } else {
          // 3) Create new user
          final insertResult = await _dbExecute(
            conn,
            'INSERT INTO `${cfg.table}` (`${cfg.emailColumn}`, `${cfg.nameColumn}`, `${cfg.providerColumn}`, `${cfg.providerIdColumn}`, created_at) VALUES (?, ?, ?, ?, NOW())',
            [email, name, provider, providerId],
          );
          userId = insertResult.insertId ?? await _getLastInsertId(conn);
          userRow = (await _dbQuery(
                  conn,
                  'SELECT * FROM `${cfg.table}` WHERE id = ? LIMIT 1',
                  [userId]))
              .first;
        }
      } else {
        // No email available: create a user with provider id only (or reject)
        final insertResult = await _dbExecute(
          conn,
          'INSERT INTO `${cfg.table}` (`${cfg.nameColumn}`, `${cfg.providerColumn}`, `${cfg.providerIdColumn}`, created_at) VALUES (?, ?, ?, NOW())',
          [name, provider, providerId],
        );
        userId = insertResult.insertId ?? await _getLastInsertId(conn);
        userRow = (await _dbQuery(conn,
                'SELECT * FROM `${cfg.table}` WHERE id = ? LIMIT 1', [userId]))
            .first;
      }
    }

    // Build payload and token
    final payload = {
      'id': userRow['id'],
      'email': userRow[cfg.emailColumn],
      'provider': provider,
    };

    final token = FlintJwt("sdf").generateToken(payload);

    return {'token': token, 'user': payload};
  }

  /// Ensures that the database table has the required columns for social logins.
  ///
  /// This is an internal helper that automatically adds `provider` and
  /// `provider_id` columns if they do not already exist, making the framework
  /// easier to use out of the box.
  static Future<void> _ensureProviderColumns() async {
    final cfg = config;

    final columns = await DBUtils.getColumns(cfg.table);

    if (cfg.providerColumn != null && !columns.contains(cfg.providerColumn)) {
      await DB.instance.execute(
          'ALTER TABLE ${cfg.table} ADD COLUMN ${cfg.providerColumn} VARCHAR(50) NULL');
    }

    if (cfg.providerIdColumn != null &&
        !columns.contains(cfg.providerIdColumn)) {
      await DB.instance.execute(
          'ALTER TABLE ${cfg.table} ADD COLUMN ${cfg.providerIdColumn} VARCHAR(255) NULL');
    }
  }

  // ---------- helpers ----------

  /// Verifies a Google ID token by calling Google's tokeninfo endpoint.
  ///
  /// @param idToken The ID token to verify.
  /// @returns A map containing the user's Google profile information.
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
    final map = jsonDecode(body) as Map<String, dynamic>;
    return map;
  }

  /// Exchanges an authorization code for an access token and ID token from Google.
  ///
  /// @param code The authorization code.
  /// @param clientId The Google client ID.
  /// @param clientSecret The Google client secret.
  /// @param redirectUri The callback URI.
  /// @returns A map containing the tokens received from Google.
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

  /// Fetches a user's profile from Google using an access token.
  ///
  /// @param accessToken The access token obtained from Google.
  /// @returns A map containing the user's profile information.
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

  /// Executes a database query and returns the results.
  static Future<List<Map<String, dynamic>>> _dbQuery(
    dynamic conn,
    String sql,
    List<dynamic> params,
  ) async {
    try {
      final rows = await conn.query(sql, params);
      return List<Map<String, dynamic>>.from(
          rows.map((r) => Map<String, dynamic>.from(r)));
    } catch (_) {
      final stmt = await conn.prepare(sql);
      final res = await stmt.execute(params);
      final list =
          res.rows.map((r) => r.assoc()).toList().cast<Map<String, dynamic>>();
      return list;
    }
  }

  /// Executes a database command (e.g., INSERT, UPDATE) and returns the result.
  static Future<dynamic> _dbExecute(
      dynamic conn, String sql, List<dynamic> params) async {
    try {
      final res = await conn.query(sql, params);
      return res;
    } catch (_) {
      final stmt = await conn.prepare(sql);
      final r = await stmt.execute(params);
      return r;
    }
  }

  /// Retrieves the last inserted ID from the database.
  static Future<int> _getLastInsertId(dynamic conn) async {
    final rows = await _dbQuery(conn, 'SELECT LAST_INSERT_ID() as id', []);
    return rows.first['id'] as int;
  }
}
