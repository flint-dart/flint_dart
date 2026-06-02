import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers = {};
  ContentType? _contentType;
  int? _contentLength;

  @override
  ContentType? get contentType => _contentType;

  @override
  int get contentLength => _contentLength ?? -1;

  @override
  set contentLength(int value) {
    _contentLength = value;
    set(HttpHeaders.contentLengthHeader, value.toString());
  }

  @override
  set contentType(ContentType? value) {
    _contentType = value;
    if (value != null) {
      set(HttpHeaders.contentTypeHeader, value.toString());
    }
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    final key = name.toLowerCase();
    _headers.putIfAbsent(key, () => []).add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name.toLowerCase()] = [value.toString()];
  }

  @override
  String? value(String name) {
    final values = _headers[name.toLowerCase()];
    if (values == null || values.isEmpty) return null;
    return values.join(', ');
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach(action);
  }

  @override
  List<String>? operator [](String name) => _headers[name.toLowerCase()];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHttpResponse implements HttpResponse {
  @override
  final FakeHttpHeaders headers = FakeHttpHeaders();

  @override
  int statusCode = 200;

  final StringBuffer buffer = StringBuffer();
  final List<int> bodyBytes = [];
  bool closed = false;

  @override
  void write(Object? obj) {
    final value = obj.toString();
    buffer.write(value);
    bodyBytes.addAll(utf8.encode(value));
  }

  @override
  void add(List<int> data) {
    bodyBytes.addAll(data);
    buffer.write(utf8.decode(data, allowMalformed: true));
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      add(chunk);
    }
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      buffer.write(utf8.decode(chunk));
    }
  }

  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHttpConnectionInfo implements HttpConnectionInfo {
  @override
  final InternetAddress remoteAddress;

  @override
  final int remotePort;

  FakeHttpConnectionInfo({
    InternetAddress? remoteAddress,
    this.remotePort = 12345,
  }) : remoteAddress = remoteAddress ?? InternetAddress.loopbackIPv4;

  @override
  int get localPort => throw UnimplementedError();
}

class FakeHttpRequest extends Stream<Uint8List> implements HttpRequest {
  final Stream<Uint8List> _stream;

  @override
  final FakeHttpHeaders headers;

  @override
  final HttpResponse response;

  @override
  final Uri uri;

  @override
  final String method;

  @override
  final HttpConnectionInfo? connectionInfo;

  FakeHttpRequest({
    required this.method,
    required this.uri,
    List<int>? bodyBytes,
    FakeHttpHeaders? headers,
    HttpResponse? response,
    HttpConnectionInfo? connectionInfo,
  })  : headers = headers ?? FakeHttpHeaders(),
        response = response ?? FakeHttpResponse(),
        connectionInfo = connectionInfo ?? FakeHttpConnectionInfo(),
        _stream = Stream<Uint8List>.fromIterable(
          bodyBytes == null ? const [] : [Uint8List.fromList(bodyBytes)],
        );

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeWebSocket implements WebSocket {
  final StreamController<dynamic> _incoming = StreamController<dynamic>();
  final List<dynamic> sent = [];

  void emitIncoming(dynamic message) {
    _incoming.add(message);
  }

  @override
  void add(dynamic data) {
    sent.add(data);
  }

  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (final item in stream) {
      add(item);
    }
  }

  @override
  StreamSubscription<dynamic> listen(void Function(dynamic event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _incoming.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Future close([int? code, String? reason]) async {
    await _incoming.close();
  }

  @override
  Future get done => _incoming.done;

  @override
  int get readyState => WebSocket.open;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<int> utf8Bytes(String value) => utf8.encode(value);
