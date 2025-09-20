import 'package:flint_dart/flint_dart.dart';
import 'package:sample/src/controllers/auth_controller.dart';

void authRoutes(Flint app) {
  final authController = AuthController();

  app.post("/register", authController.register);

  app.post("/login", authController.login);

  app.post("/login-with-google", authController.login);
}
