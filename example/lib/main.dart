import 'package:flint_dart/flint_dart.dart';
import 'package:sample/src/middlewares/auth_middleware.dart';
import 'package:sample/src/routes/auth_routes.dart';
import 'package:sample/src/routes/user_routes.dart';

void main() {
  final app = Flint(
      withDefaultMiddleware: true,
      enableSwaggerDocs: true,
      autoConnectDb: true);

  app.get('/', (req, res) async {
    return res.send('Hello from FlintDart!');
  });
  app.mount(
    "/users",
    registerUserRoutes,
  );
  app.get('/profile', (req, res) async {
    return res.json({'msg': 'This is a protected route'});
  }).useMiddleware(AuthMiddleware());

  app.mount("/auth", authRoutes);
  app.listen(4000);
}
