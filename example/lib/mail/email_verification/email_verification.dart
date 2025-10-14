import 'package:flint_dart/mail.dart';

class EmailVerificationMail extends Mailable {
  final String recipientName;
  final String recipientEmail;

  EmailVerificationMail({
    required this.recipientName,
    required this.recipientEmail,
  });

  @override
  String get subject => 'Email Verification';

  @override
  String get view => 'mail/email_verification/view.flint.html';

  @override
  Map<String, dynamic> get data => {
    'recipientName': recipientName,
    'recipientEmail': recipientEmail,
    'currentYear': DateTime.now().year,
  };

  @override
  List<String> get to => [recipientEmail];
}