import 'package:flint_dart/mail.dart';

class WalesMail extends ViewMailable {
  final String recipientName;
  final String recipientEmail;

  WalesMail({
    required this.recipientName,
    required this.recipientEmail,
  });

  @override
  String get subject => 'Wales';

  @override
  String get view => 'mail/views/wales.flint.html';

  @override
  Map<String, dynamic> get data => {
        'recipientName': recipientName,
        'recipientEmail': recipientEmail,
        'currentYear': DateTime.now().year,
      };

  @override
  List<String> get to => [recipientEmail];
}
