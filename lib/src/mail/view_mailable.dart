// lib/mail/view_mailable.dart

import 'package:flint_dart/mail.dart';
import 'package:flint_dart/src/template_engine/template.dart';

/// Represents an email built from an HTML view template (.flint.html)
abstract class ViewMailable {
  /// The email subject line
  String get subject;

  /// The recipients
  List<String> get to;

  /// Optional CC recipients
  List<String> get cc => [];

  /// Optional BCC recipients
  List<String> get bcc => [];

  /// Path to the view file, e.g. `mail/views/welcome.flint.html`
  String get view;

  /// Data for interpolation inside the template
  Map<String, dynamic> get data;

  /// Optional sender email and name
  String? get from => null;
  String? get fromName => null;

  /// Optional reply-to email
  String? get replyTo => null;

  /// Optional attachments
  List<MailAttachment> get attachments => [];

  /// Priority (default: normal)
  MailPriority get priority => MailPriority.normal;

  /// Send immediately
  Future<void> send() async {
    try {
      validate();

      // Render .flint.html template into HTML
      final html = FlintTemplateEngine.render(view, data: data);
      final text = _stripHtmlTags(html);

      final mail = Mail().toMany(to).subject(subject).html(html).text(text);

      if (cc.isNotEmpty) mail.ccMany(cc);
      if (bcc.isNotEmpty) mail.bccMany(bcc);

      await mail.sendMail();
      print('✅ Email sent to: ${to.join(', ')}');
    } catch (e) {
      print('❌ Failed to send view mail: $e');
      rethrow;
    }
  }

  /// Queue the mail for later
  Future<void> queue() async {
    try {
      validate();

      final html = FlintTemplateEngine.render(view, data: data);
      final text = _stripHtmlTags(html);

      final mail = Mail().toMany(to).subject(subject).html(html).text(text);

      await mail.queue();
      print('📬 View mail queued for: ${to.join(', ')}');
    } catch (e) {
      print('❌ Failed to queue view mail: $e');
      rethrow;
    }
  }

  /// Validate required data
  void validate() {
    if (to.isEmpty) {
      throw Exception('At least one recipient is required in "to"');
    }
    if (subject.isEmpty) {
      throw Exception('Subject cannot be empty');
    }
    if (view.isEmpty) {
      throw Exception('View path cannot be empty');
    }
  }

  /// Strip HTML tags for plain-text fallback
  String _stripHtmlTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }
}
