import 'dart:math';
import 'package:flint_dart/auth.dart';
import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/database/orm/query_builder.dart';
import 'package:flint_dart/src/error/auth_exception.dart';

extension AuthVerification on Auth {
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
      throw AuthException('No account found for this email.');
    }

    // Generate numeric code
    final rng = Random();
    final code = List.generate(length, (_) => rng.nextInt(10)).join('');

    // Hash code before storing
    final codeHash = Hashing().hash(code);

    // Expire after 10 minutes
    final expiresAt =
        DateTime.now().add(Duration(minutes: 10)).toIso8601String();

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

    final codeHash = Hashing().hash(code);

    // Find matching valid record
    final record = await QueryBuilder(table: 'email_verification_tokens')
        .where('email', '=', email)
        .where('token', '=', codeHash)
        .where('expires_at', '>', DateTime.now().toIso8601String())
        .first();

    if (record == null) {
      Log.debug('❌ Invalid or expired verification code for $email');
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
      throw AuthException('No account found for this email.');
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
          'Password must be at least ${Auth.config.passwordMinLength} characters.');
    }

    final codeHash = Hashing().hash(code);

    // Look for valid code
    final record = await QueryBuilder(table: 'password_reset_tokens')
        .where('email', '=', email)
        .where('token', '=', codeHash)
        .where('expires_at', '>', DateTime.now().toIso8601String())
        .first();

    if (record == null) {
      Log.debug('❌ Invalid or expired password reset code for $email');
      throw AuthException('Invalid or expired reset code.');
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
}
