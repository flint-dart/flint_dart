import 'package:flint_dart/flint_dart.dart';
import 'package:sample/controllers/ai_runtime_controller.dart';

class AiRoutes extends RouteGroup {
  @override
  String get prefix => '/ai-demo';

  @override
  void register(Flint app) {
    app.get('/', controllerAction(AiRuntimeController.new, (c) => c.index()));
    app.get(
      '/runtime',
      controllerAction(AiRuntimeController.new, (c) => c.runtime()),
    );
    app.get(
      '/workflow',
      controllerAction(AiRuntimeController.new, (c) => c.workflow()),
    );
    app.get(
      '/chat',
      controllerAction(AiRuntimeController.new, (c) => c.chat()),
    );
    app.post(
      '/support',
      controllerAction(AiRuntimeController.new, (c) => c.support()),
    );
  }
}
