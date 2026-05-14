import 'package:flint_dart/src/swagger_gen/route_parser.dart';
import 'package:flint_dart/src/swagger_gen/swagger_generator.dart';
import 'package:test/test.dart';

void main() {
  group('Swagger websocket docs', () {
    test('route parser documents websocket routes as websocket-aware GETs', () {
      final parser = RouteParser();
      final generator = SwaggerGenerator();

      parser.parseFile([
        "import 'package:flint_dart/flint_dart.dart';",
        '',
        'class ChatRoutes extends RouteGroup {',
        '  @override',
        "  String get prefix => '/ws';",
        '',
        '  @override',
        "  String get tag => 'Chat';",
        '',
        '  @override',
        '  void register(Flint app) {',
        '    /// @summary Chat websocket handshake',
        "    app.websocket('/chat/:room', (ctx) {});",
        '  }',
        '}',
      ], generator);

      final swagger = generator.generateSwagger();
      final operation =
          (swagger['paths'] as Map<String, dynamic>)['/ws/chat/{room}']['get']
              as Map<String, dynamic>;
      final websocketEntry = (swagger['x-websockets']
          as Map<String, dynamic>)['/ws/chat/{room}'] as Map<String, dynamic>;

      expect(operation['summary'], 'Chat websocket handshake');
      expect(operation['x-websocket'], isTrue);
      expect(operation['x-flint-transport'], 'websocket');
      expect(operation['x-flint-namespace'], '/ws/chat/{room}');
      expect(operation['tags'], ['Chat']);
      expect(
          operation['responses']['101']['description'], 'Switching Protocols');

      expect(websocketEntry['x-websocket'], isTrue);
      expect(websocketEntry['responses']['101']['description'],
          'Switching Protocols');
    });

    test('generator keeps websocket routes in Flint extension docs', () {
      final generator = SwaggerGenerator();

      final websocketOperation = generator.createOperation(
        summary: 'Notification socket',
        tags: ['Notifications'],
        responses: {
          '200': {'description': 'Socket available'}
        },
        fullPath: '/notifications',
        isWebSocket: true,
      );

      generator.addRoute(
        '/notifications',
        'get',
        websocketOperation,
        const ['https://example.com'],
        isWebSocket: true,
      );

      final swagger = generator.generateSwagger();
      final pathOperation =
          (swagger['paths'] as Map<String, dynamic>)['/notifications']['get']
              as Map<String, dynamic>;
      final websocketOperationDoc = (swagger['x-websockets']
          as Map<String, dynamic>)['/notifications'] as Map<String, dynamic>;

      expect(pathOperation['x-websocket'], isTrue);
      expect(pathOperation['responses']['101']['description'],
          'Switching Protocols');
      expect(websocketOperationDoc['x-flint-transport'], 'websocket');
      expect((swagger['servers'] as List).single['url'], 'https://example.com');
    });
  });
}
