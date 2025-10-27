import 'package:flint_dart/flint_dart.dart';
import 'package:sample/src/controllers/post_controller.dart';

void postRoute(Flint app) {
  app.get("/", PostController().index);
  app.post("/", PostController().store);
  app.put("/:id", PostController().update);
}
