import 'package:flint_dart/mail.dart';

class PasswordResetMail extends Mailable {
  final String recipientName;
  final String recipientEmail;

  PasswordResetMail({
    required this.recipientName,
    required this.recipientEmail,
  });

  @override
  String get subject => 'Password Reset';

  @override
  String get view => 'mail/password_reset/view.flint.html';

  @override
  Map<String, dynamic> get data => {
    'recipientName': recipientName,
    'recipientEmail': recipientEmail,
    'currentYear': DateTime.now().year,
  };

  @override
  List<String> get to => [recipientEmail];
}