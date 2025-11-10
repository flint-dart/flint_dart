import 'package:flint_dart/auth.dart';
import 'package:flint_dart/flint_dart.dart';

class AuthController {
  Future<Response> register(Request req, Response res) async {
    var data = await req.validate({
      "name": "string|required",
      "email": "string|required",
      "password": "string|required|confirmed",
    });

    var user = await Auth.register(
      email: data["email"],
      password: data['password'],
      name: data["name"],
    );

    // Send welcome email
    // await _sendWelcomeEmail(data);

    // final otp = await Auth.generateNumericVerificationCode(data["email"]);

    // var mail = WelcomeMail(
    //   recipientName: 'Preview User',
    //   recipientEmail: 'preview@example.com',
    //   verificationUrl: 'https://example.com/verify/preview',
    //   loginUrl: 'https://example.com/login',
    // );

    // await mail.send();

    // await OtpModel().create({
    //   "email": data["email"],
    //   "otp": otp.toString(),
    //   "expired_at": DateTime.now().add(Duration(minutes: 20)).toIso8601String()
    // });
    return res.respond({"msg": "User created successfully", "data": user});
  }

  Future<Response> login(Request req, Response res) async {
    final data = await req.validate({
      "email": "required|string",
      "password": "required|string", // Fixed typo here
    });

    final user = await Auth.login(
        data["email"], data["password"]); // Fixed password reference

    return res.respond({"msg": "Login successful", "data": user});
  }

  Future<Response> forgotPassword(Request req, Response res) async {
    final data = await req.validate({
      "email": "required|string|confirmed",
    });

    // Generate password reset token
    final resetToken = await Auth.generatePasswordResetToken(data["email"]);

    if (resetToken != null) {
      // Send password reset email
      await _sendPasswordResetEmail(data["email"], resetToken);
    }

    // Always return success to prevent email enumeration
    return res.respond({
      "msg":
          "If an account with that email exists, a password reset link has been sent"
    });
  }

  Future<Response> resetPassword(Request req, Response res) async {
    final data = await req.validate({
      "token": "required|string",
      "password": "required|string|confirmed",
    });
    final success = await Auth.resetPassword(
      token: data["token"],
      newPassword: data["password"],
    );

    if (success) {
      return res.respond({"msg": "Password reset successfully"});
    } else {
      return res
          .respond({"msg": "Invalid or expired reset token"}, status: 400);
    }
  }

  // Private email methods
  // Future<void> _sendWelcomeEmail(user) async {
  //   try {
  //     Mail().to(user["email"]).subject("Welcome").text("testing").sendMail();

  //     print('✅ Welcome email sent to ${user['email']}');
  //   } catch (e) {
  //     print('⚠️ Failed to send welcome email: $e');
  //     // Don't throw - email failure shouldn't break registration
  //   }
  // }

  Future<void> _sendPasswordResetEmail(String email, String resetToken) async {
    try {
      final resetUrl = 'https://yourapp.com/reset-password?token=$resetToken';

      print('✅ $resetUrl Password reset email sent to $email');
    } catch (e) {
      print('⚠️ Failed to send password reset email: $e');
    }
  }

  Future<Response> resendVerification(Request req, Response res) async {
    final data = await req.validate({
      "email": "required|string",
    });

    // In a real app, you might want to check if user exists and is unverified
    final verificationToken =
        await Auth.generateEmailVerificationToken(data["email"]);

    if (verificationToken != null) {
      await _sendVerificationEmail(data["email"], verificationToken);
    }

    return res.respond({
      "msg":
          "If an account with that email exists, a verification email has been sent"
    });
  }

  Future<void> _sendVerificationEmail(
      String email, String verificationToken) async {
    try {
      final verificationUrl =
          'https://yourapp.com/verify-email?token=$verificationToken';

      print('✅ link:$verificationUrl Verification email sent to $email');
    } catch (e) {
      print('⚠️ Failed to send verification email: $e');
    }
  }
}
