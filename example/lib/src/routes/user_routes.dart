import 'package:flint_dart/flint_dart.dart';
import 'package:sample/src/middlewares/auth_middleware.dart';
import '../controllers/user_controller.dart';

void registerUserRoutes(Flint app) {
  final controller = UserController();

  /// @summary Register a new user
  /// @server http://localhost:3000
  /// @server https://api.mydomain.com
  /// @prefix /users
  app.get("/", controller.index).useMiddleware(AuthMiddleware());

  /// @summary Get a user by ID
  /// @prefix /users
  app
      .get("/:id", controller.show)
      .useMiddleware(AuthMiddleware())
      .useMiddleware(LoggerMiddleware());

  /// @prefix /users
  /// @summary Create a new user
  /// @response 200 User registered successfully
  /// @response 404 User not found
  /// @response 202 User is avai
  /// @body {"email": "string", "password": "string"}
  app.post('/', controller.create);

  /// @prefix /users
  app.put('/:id', controller.create);

  /// @prefix /users
  /// @auth basicAuth
  app.delete('/:id', controller.delete).useMiddleware(AuthMiddleware());
}
