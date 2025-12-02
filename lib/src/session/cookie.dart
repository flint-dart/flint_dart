class Cookie {
  final String name;
  final String value;
  final DateTime? expires;
  final String path;
  final bool httpOnly;
  final bool secure;

  Cookie({
    required this.name,
    required this.value,
    this.expires,
    this.path = '/',
    this.httpOnly = true,
    this.secure = false,
  });

  @override
  String toString() {
    String cookie = '$name=$value; Path=$path;';
    if (expires != null) cookie += ' Expires=${expires!.toUtc().toIso8601String()};';
    if (httpOnly) cookie += ' HttpOnly;';
    if (secure) cookie += ' Secure;';
    return cookie;
  }

  static Map<String, String> parse(String cookieHeader) {
    final Map<String, String> cookies = {};
    final parts = cookieHeader.split(';');
    for (var part in parts) {
      var pair = part.trim().split('=');
      if (pair.length == 2) cookies[pair[0]] = pair[1];
    }
    return cookies;
  }
}
