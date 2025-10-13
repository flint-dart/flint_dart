import 'dart:io';

class MailTemplate {
  static Future<String> render(String path, Map<String, String> data) async {
    String html = await File(path).readAsString();
    data.forEach((key, value) {
      html = html.replaceAll('{{$key}}', value);
    });
    return html;
  }
}
