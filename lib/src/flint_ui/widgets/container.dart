import 'package:flint_dart/flint_ui.dart';

/// Base container with layout capabilities
abstract class FlintContainer extends FlintWidget {
  final List<FlintWidget> children;

  FlintContainer({
    required this.children,
  });
}
