// lib/flint_ui/builders/spacing_builder.dart

import 'package:flint_dart/src/flint_ui/core/edge_insets.dart';

class SpacingBuilder {
  /// Create responsive spacing that adapts to screen size
  static EdgeInsets responsive({
    double mobile = 16.0,
    double tablet = 24.0,
    double desktop = 32.0,
  }) {
    // For email, we'll use mobile-first approach
    // In future, we can make this responsive with media queries
    return EdgeInsets.all(mobile);
  }

  /// Create spacing for text elements with proper vertical rhythm
  static EdgeInsets textSpacing({
    TextSpacingType type = TextSpacingType.paragraph,
  }) {
    switch (type) {
      case TextSpacingType.headline:
        return EdgeInsets.symmetric(vertical: 24.0);
      case TextSpacingType.subhead:
        return EdgeInsets.symmetric(vertical: 20.0);
      case TextSpacingType.paragraph:
        return EdgeInsets.symmetric(vertical: 16.0);
      case TextSpacingType.caption:
        return EdgeInsets.symmetric(vertical: 12.0);
      case TextSpacingType.listItem:
        return EdgeInsets.symmetric(vertical: 8.0);
    }
  }

  /// Create spacing for card layouts
  static EdgeInsets cardSpacing({
    CardSpacingType type = CardSpacingType.standard,
  }) {
    switch (type) {
      case CardSpacingType.compact:
        return EdgeInsets.all(12.0);
      case CardSpacingType.standard:
        return EdgeInsets.all(16.0);
      case CardSpacingType.comfortable:
        return EdgeInsets.all(24.0);
      case CardSpacingType.spacious:
        return EdgeInsets.all(32.0);
    }
  }

  /// Create spacing for form elements
  static EdgeInsets formSpacing({
    FormSpacingType type = FormSpacingType.standard,
  }) {
    switch (type) {
      case FormSpacingType.compact:
        return EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0);
      case FormSpacingType.standard:
        return EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0);
      case FormSpacingType.comfortable:
        return EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0);
    }
  }

  /// Create spacing for grid systems
  static EdgeInsets gridSpacing({
    GridSpacingType type = GridSpacingType.standard,
  }) {
    switch (type) {
      case GridSpacingType.tight:
        return EdgeInsets.all(8.0);
      case GridSpacingType.standard:
        return EdgeInsets.all(16.0);
      case GridSpacingType.loose:
        return EdgeInsets.all(24.0);
    }
  }
}

enum TextSpacingType {
  headline,
  subhead,
  paragraph,
  caption,
  listItem,
}

enum CardSpacingType {
  compact,
  standard,
  comfortable,
  spacious,
}

enum FormSpacingType {
  compact,
  standard,
  comfortable,
}

enum GridSpacingType {
  tight,
  standard,
  loose,
}
