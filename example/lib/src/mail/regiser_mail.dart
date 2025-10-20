import 'package:flint_dart/flint_ui.dart';
import './templates/regiser_template.dart';
import 'package:flint_dart/mail.dart';

class RegiserMail extends TransactionalMailable {
  final String title;
  final String content;
  final String? imageUrl;

  RegiserMail({
    required super.recipientEmail,
    required super.recipientName,
    required this.title,
    required this.content,
    this.imageUrl,
  });

  @override
  String get subject => title;

  @override
  FlintWidget build() {
    return RegiserTemplate(
      title: title,
      content: content,
      imageUrl: imageUrl,
    );
  }
}
