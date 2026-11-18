import 'package:flint_dart/flint_dart.dart';
import 'package:sample/controllers/post_controller.dart';

class PostRoutes extends RouteGroup {
  @override
  String get prefix => '/post';

  @override
  void register(Flint app) {
    app.get("/", PostController().index);
    app.post("/", PostController().store);
    app.put("/:id", PostController().update);
  }
}
