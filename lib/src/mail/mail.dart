import 'dart:async';
import 'dart:isolate';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class Mail {
  static SmtpServer? _server;
  static String? _from;

  final List<String> _to = [];
  final List<String> _cc = [];
  final List<String> _bcc = [];
  String? _subject;
  String? _html;
  String? _text;

  Mail();

  // ---- Static configuration ----
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
  }

  // ---- Chainable API ----
  Mail to(String email) {
    _to.add(email);
    return this;
  }

  /// Add multiple recipients at once
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

  // ---- Fallback logic ----
  Message _buildMessage() {
    final message = Message()
      ..from = Address(_from ?? '')
      ..recipients.addAll(_to)
      ..ccRecipients.addAll(_cc)
      ..bccRecipients.addAll(_bcc)
      ..subject = _subject ?? '';

    // Fallback: if only HTML is provided, extract plain text automatically
    if (_html != null && _text == null) {
      final plain = _html!
          .replaceAll(RegExp(r'<[^>]*>'), '') // strip tags
          .replaceAll('&nbsp;', ' ')
          .trim();
      message.text = plain;
    } else if (_text != null) {
      message.text = _text;
    }

    if (_html != null) message.html = _html;

    return message;
  }

  // ---- Send immediately ----
  Future<void> sendMail() async {
    if (_server == null) {
      throw Exception('Mail not configured. Call Mail.setup() first.');
    }

    final message = _buildMessage();

    try {
      await send(message, _server!);
      print('✅ Mail sent to: ${_to.join(", ")}'
          '${_cc.isNotEmpty ? ", cc: ${_cc.join(", ")}" : ""}'
          '${_bcc.isNotEmpty ? ", bcc: ${_bcc.join(", ")}" : ""}');
    } catch (e) {
      print('❌ Failed to send mail: $e');
    }
  }

  // ---- Send asynchronously (queue) ----
  Future<void> queue() async {
    if (_server == null) {
      throw Exception('Mail not configured. Call Mail.setup() first.');
    }

    final message = _buildMessage();

    final serverData = {
      'host': _server!.host,
      'port': _server!.port,
      'username': _server!.username,
      'password': _server!.password,
      'ssl': _server!.ssl,
    };

    await Isolate.spawn(_sendInBackground, {
      'message': message,
      'server': serverData,
    });
  }

  // ---- Isolate worker ----
  static Future<void> _sendInBackground(Map data) async {
    final msg = data['message'] as Message;
    final serverData = data['server'] as Map;
    final server = SmtpServer(
      serverData['host'],
      port: serverData['port'],
      username: serverData['username'],
      password: serverData['password'],
      ssl: serverData['ssl'],
    );

    try {
      await send(msg, server);
      print('📬 [Queued] Mail sent to: ${msg.recipients}');
    } catch (e) {
      print('⚠️ [Queued] Failed to send mail: $e');
    }
  }
}
