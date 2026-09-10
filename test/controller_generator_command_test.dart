import 'dart:io';

import 'package:flint_dart/src/cli/make_controller_command.dart';
import 'package:flint_dart/src/cli/make_middleware_command.dart';
import 'package:flint_dart/src/cli/make_resource_command.dart';
import 'package:flint_dart/src/cli/make_route_command.dart';
import 'package:test/test.dart';

void main() {
  late Directory originalCurrent;
  late Directory tempDir;

  setUp(() async {
    originalCurrent = Directory.current;
    tempDir =
        await Directory.systemTemp.createTemp('flint_controller_generator_');
    Directory.current = tempDir;
  });

  tearDown(() async {
    Directory.current = originalCurrent;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('make:controller creates a request-scoped Controller subclass',
      () async {
    await MakeControllerCommand().execute(['CourseController']);

    final file = File('lib/controllers/course_controller.dart');
    expect(await file.exists(), isTrue);

    final content = await file.readAsString();
    expect(content, contains('class CourseController extends Controller'));
    expect(content, contains('Future<Response> index() async'));
    expect(content, contains("res.send('Listing all items...')"));
    expect(content, isNot(contains('Request req, Response res')));
  });

  test('make:middleware creates a Context-based WebSocket-safe template',
      () async {
    await MakeMiddlewareCommand().execute(['AuthMiddleware']);

    final file = File('lib/middlewares/auth_middleware.dart');
    expect(await file.exists(), isTrue);

    final content = await file.readAsString();
    expect(content, contains('class AuthMiddleware extends Middleware'));
    expect(content, contains('return (Context ctx) async'));
    expect(content, contains('return await next(ctx);'));
    expect(content, contains("ctx.req.bearerToken"));
    expect(content, isNot(contains('if (res == null) return null')));
    expect(content, isNot(contains('Request req, Response res')));
  });

  test('make:route uses app.controller route registration', () async {
    await MakeRouteCommand().execute(['Course']);

    final file = File('lib/routes/course_routes.dart');
    expect(await file.exists(), isTrue);

    final content = await file.readAsString();
    expect(
        content, contains("import '../controllers/course_controller.dart';"));
    expect(content,
        contains('final routes = app.controller(CourseController.new);'));
    expect(
      content,
      contains("routes.get('/', (controller) => controller.index());"),
    );
    expect(content, contains('/// @summary List Course'));
    expect(content, contains('/// @query page integer optional Page number'));
    expect(
      content,
      contains('/// @param id path string required Course ID'),
    );
    expect(content, isNot(contains('@prefix /api')));
    expect(content, isNot(contains('final controller = CourseController()')));
    expect(content, isNot(contains("app.get('/', controller.index)")));
  });

  test('make:resource creates current controller and route templates',
      () async {
    final appRoutes = File('lib/routes/app_routes.dart');
    await appRoutes.create(recursive: true);
    await appRoutes.writeAsString('''
import 'package:flint_dart/flint_dart.dart';

void register(Flint app) {
}
''');

    await MakeResourceCommand().execute(['Course']);

    final controller = File('lib/controllers/course_controller.dart');
    final routes = File('lib/routes/course_routes.dart');

    expect(await controller.exists(), isTrue);
    expect(await routes.exists(), isTrue);

    final controllerContent = await controller.readAsString();
    expect(controllerContent,
        contains('class CourseController extends Controller'));
    expect(controllerContent, contains('Future<Response> show() async'));
    expect(controllerContent, isNot(contains('Request req, Response res')));

    final routesContent = await routes.readAsString();
    expect(routesContent,
        contains('final routes = app.controller(CourseController.new);'));
    expect(
      routesContent,
      contains("routes.post('/', (controller) => controller.create());"),
    );
    expect(routesContent, contains('/// @summary List Course'));
    expect(routesContent, contains('/// @summary Create Course'));
    expect(
      routesContent,
      contains('/// @param id path string required Course ID'),
    );
    expect(routesContent, isNot(contains('@prefix /api')));
    expect(routesContent, isNot(contains('CourseController()')));

    final appRoutesContent = await appRoutes.readAsString();
    expect(appRoutesContent, contains("import 'course_routes.dart';"));
    expect(appRoutesContent,
        contains("import 'package:flint_dart/flint_dart.dart';"));
    expect(appRoutesContent, contains('app.routes(CourseRoutes());'));
    expect(appRoutesContent, isNot(contains(r'\1')));
    expect(appRoutesContent, isNot(contains('eucloudhost')));
  });
}
