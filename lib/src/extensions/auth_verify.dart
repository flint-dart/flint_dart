import 'package:flint_dart/auth.dart';

/// Backward-compatible extension wrappers.
///
/// The source of truth for verification/reset flows is now `Auth` to avoid
/// drift between duplicated implementations.
extension AuthVerification on Auth {
  static Future<String> generateNumericVerificationCode(
    String email, {
    int length = 6,
  }) {
    return Auth.generateNumericVerificationCode(email, length: length);
  }

  static Future<bool> verifyNumericCode(String email, String code) {
    return Auth.verifyNumericCode(email, code);
  }

  static Future<String> resendVerificationCode(String email) {
    return Auth.resendVerificationCode(email);
  }

  static Future<String> generatePasswordResetCode(
    String email, {
    int length = 6,
  }) {
    return Auth.generatePasswordResetCode(email, length: length);
  }

  static Future<bool> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return Auth.resetPasswordWithCode(
      email: email,
      code: code,
      newPassword: newPassword,
    );
  }

  static Future<String> resendPasswordResetCode(String email) {
    return Auth.resendPasswordResetCode(email);
  }
}
