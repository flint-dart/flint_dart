import 'package:flint_dart/flint_dart.dart';
import 'package:sample/controllers/auth_controller.dart';

class AuthRoutes extends RouteGroup {
  @override
  String get prefix => '/auth';

  @override
  void register(Flint app) {
    final authController = AuthController();
    app.post("/register", authController.register);
    app.post("/login", authController.login);
  }
}
