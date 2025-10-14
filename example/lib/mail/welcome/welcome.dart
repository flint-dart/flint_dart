import 'package:flint_dart/mail.dart';

class WelcomeMail extends Mailable {
  final String recipientName;
  final String recipientEmail;

  WelcomeMail({
    required this.recipientName,
    required this.recipientEmail,
  });

  @override
  String get subject => 'Welcome';

  @override
  String get view => 'mail/welcome/view.flint.html';

  @override
  Map<String, dynamic> get data => {
    'recipientName': recipientName,
    'recipientEmail': recipientEmail,
    'currentYear': DateTime.now().year,
  };

  @override
  List<String> get to => [recipientEmail];
}