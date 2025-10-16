// lib/flint_ui/core/spacing.dart

import 'package:flint_dart/src/flint_ui/core/edge_insets.dart';

class FlintSpacing {
  // Base spacing unit (8px grid system)
  static const double unit = 8.0;

  // Common spacing presets
  static const EdgeInsets zero = EdgeInsets.zero();

  static const EdgeInsets xs = EdgeInsets.all(unit * 0.5); // 4px
  static const EdgeInsets sm = EdgeInsets.all(unit * 1); // 8px
  static const EdgeInsets md = EdgeInsets.all(unit * 1.5); // 12px
  static const EdgeInsets lg = EdgeInsets.all(unit * 2); // 16px
  static const EdgeInsets xl = EdgeInsets.all(unit * 3); // 24px
  static const EdgeInsets xxl = EdgeInsets.all(unit * 4); // 32px

  // Horizontal only
  static const EdgeInsets horizontalXs =
      EdgeInsets.symmetric(horizontal: unit * 0.5);
  static const EdgeInsets horizontalSm =
      EdgeInsets.symmetric(horizontal: unit * 1);
  static const EdgeInsets horizontalMd =
      EdgeInsets.symmetric(horizontal: unit * 1.5);
  static const EdgeInsets horizontalLg =
      EdgeInsets.symmetric(horizontal: unit * 2);
  static const EdgeInsets horizontalXl =
      EdgeInsets.symmetric(horizontal: unit * 3);

  // Vertical only
  static const EdgeInsets verticalXs =
      EdgeInsets.symmetric(vertical: unit * 0.5);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: unit * 1);
  static const EdgeInsets verticalMd =
      EdgeInsets.symmetric(vertical: unit * 1.5);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: unit * 2);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: unit * 3);

  // Top only
  static const EdgeInsets topXs = EdgeInsets.top(unit * 0.5);
  static const EdgeInsets topSm = EdgeInsets.top(unit * 1);
  static const EdgeInsets topMd = EdgeInsets.top(unit * 1.5);
  static const EdgeInsets topLg = EdgeInsets.top(unit * 2);
  static const EdgeInsets topXl = EdgeInsets.top(unit * 3);

  // Right only
  static const EdgeInsets rightXs = EdgeInsets.right(unit * 0.5);
  static const EdgeInsets rightSm = EdgeInsets.right(unit * 1);
  static const EdgeInsets rightMd = EdgeInsets.right(unit * 1.5);
  static const EdgeInsets rightLg = EdgeInsets.right(unit * 2);
  static const EdgeInsets rightXl = EdgeInsets.right(unit * 3);

  // Bottom only
  static const EdgeInsets bottomXs = EdgeInsets.bottom(unit * 0.5);
  static const EdgeInsets bottomSm = EdgeInsets.bottom(unit * 1);
  static const EdgeInsets bottomMd = EdgeInsets.bottom(unit * 1.5);
  static const EdgeInsets bottomLg = EdgeInsets.bottom(unit * 2);
  static const EdgeInsets bottomXl = EdgeInsets.bottom(unit * 3);

  // Left only
  static const EdgeInsets leftXs = EdgeInsets.left(unit * 0.5);
  static const EdgeInsets leftSm = EdgeInsets.left(unit * 1);
  static const EdgeInsets leftMd = EdgeInsets.left(unit * 1.5);
  static const EdgeInsets leftLg = EdgeInsets.left(unit * 2);
  static const EdgeInsets leftXl = EdgeInsets.left(unit * 3);
}
