import 'package:flint_dart/mail.dart';

class EmailVerificatiosMail extends Mailable {
  final String recipientName;
  final String recipientEmail;

  EmailVerificatiosMail({
    required this.recipientName,
    required this.recipientEmail,
  });

  @override
  String get subject => 'Email Verificatios';

  @override
  String get view => 'mail/email_verificatios/view.flint.html';

  @override
  Map<String, dynamic> get data => {
    'recipientName': recipientName,
    'recipientEmail': recipientEmail,
    'currentYear': DateTime.now().year,
  };

  @override
  List<String> get to => [recipientEmail];
}