import 'dart:async';
import 'dart:isolate';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class Mail {
  // ---- Static SMTP config ----
  static SmtpServer? _server;
  static String? _from;

  final List<String> _to = [];
  final List<String> _cc = [];
  final List<String> _bcc = [];
  String? _subject;
  String? _html;
  String? _text;

  Mail();

  // ---- Setup once ----
  static void setup({
    required String host,
    required int port,
    required String username,
    required String password,
    bool useSSL = false,
    bool useTLS = true,
  }) {
    _server = SmtpServer(
      host,
      port: port,
      username: username,
      password: password,
      ssl: useSSL,
      allowInsecure: false,
    );
    _from = username;
    print('📧 Mail server configured for $_from@$host');
  }

  // ---- Chainable API ----
  Mail to(String email) {
    _to.add(email);
    return this;
  }

  Mail toMany(List<String> emails) {
    _to.addAll(emails);
    return this;
  }

  Mail cc(String email) {
    _cc.add(email);
    return this;
  }

  Mail ccMany(List<String> emails) {
    _cc.addAll(emails);
    return this;
  }

  Mail bcc(String email) {
    _bcc.add(email);
    return this;
  }

  Mail bccMany(List<String> emails) {
    _bcc.addAll(emails);
    return this;
  }

  Mail subject(String subject) {
    _subject = subject;
    return this;
  }

  Mail html(String html) {
    _html = html;
    return this;
  }

  Mail text(String text) {
    _text = text;
    return this;
  }

  // ---- Message builder ----
  Message _buildMessage() {
    if (_to.isEmpty && _cc.isEmpty && _bcc.isEmpty) {
      throw Exception('No recipients specified.');
    }

    if (_subject == null && _text == null && _html == null) {
      throw Exception('Message has no content.');
    }

    if (_from == null || _from!.isEmpty) {
      throw Exception('From address not set. Call Mail.setup() first.');
    }

    print('📧 Building message from $_from to $_to');

    final msg = Message()
      ..from = Address(_from!, 'Flint Dart')
      ..recipients.addAll(_to)
      ..ccRecipients.addAll(_cc)
      ..bccRecipients.addAll(_bcc)
      ..subject = _subject ?? '';

    if (_html != null && _text == null) {
      final plain = _html!
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&nbsp;', ' ')
          .trim();
      msg.text = plain;
    } else if (_text != null) {
      msg.text = _text;
    }

    if (_html != null) msg.html = _html;

    return msg;
  }

  // ---- Send immediately ----
  Future<void> sendMail() async {
    if (_server == null) {
      throw Exception('Mail not configured. Call Mail.setup() first.');
    }

    try {
      final msg = _buildMessage();
      await send(msg, _server!);
      print('✅ Mail sent to: ${_to.join(", ")}');
    } on MailerException catch (e) {
      print('❌ MailerException: ${e.problems.map((p) => p.code).join(", ")}');
    } catch (e) {
      print('❌ Failed to send mail: $e');
    }
  }

  // ---- Send asynchronously (background isolate) ----
  Future<void> queue() async {
    if (_server == null) {
      throw Exception('Mail not configured. Call Mail.setup() first.');
    }

    final mailData = {
      'from': _from,
      'to': _to,
      'cc': _cc,
      'bcc': _bcc,
      'subject': _subject,
      'text': _text,
      'html': _html,
    };

    final serverData = {
      'host': _server!.host,
      'port': _server!.port,
      'username': _server!.username,
      'password': _server!.password,
      'ssl': _server!.ssl,
    };

    await Isolate.spawn(_sendInBackground, {
      'message': mailData,
      'server': serverData,
    });
  }

  // ---- Background worker ----
  static Future<void> _sendInBackground(Map data) async {
    final msgData = Map<String, dynamic>.from(data['message']);
    final serverData = Map<String, dynamic>.from(data['server']);

    final msg = Message()
      ..from = Address(msgData['from'] ?? 'noreply@domain.com')
      ..recipients.addAll(List<String>.from(msgData['to'] ?? []))
      ..ccRecipients.addAll(List<String>.from(msgData['cc'] ?? []))
      ..bccRecipients.addAll(List<String>.from(msgData['bcc'] ?? []))
      ..subject = msgData['subject'] ?? ''
      ..text = msgData['text']
      ..html = msgData['html'];

    final server = SmtpServer(
      serverData['host'],
      port: serverData['port'],
      username: serverData['username'],
      password: serverData['password'],
      ssl: serverData['ssl'],
    );

    try {
      await send(msg, server);
      print('📬 [Queued] Mail sent to: ${msg.recipients.join(", ")}');
    } catch (e) {
      print('⚠️ [Queued] Failed to send mail: $e');
    }
  }
}
