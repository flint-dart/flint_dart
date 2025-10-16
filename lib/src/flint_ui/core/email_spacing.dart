// lib/flint_ui/core/email_spacing.dart

import 'package:flint_dart/src/flint_ui/core/edge_insets.dart';

class EmailSpacing {
  // Email-specific spacing (more conservative for email clients)
  static const EdgeInsets emailSafe = EdgeInsets.all(16.0);
  static const EdgeInsets emailSection = EdgeInsets.symmetric(vertical: 24.0);
  static const EdgeInsets emailContent = EdgeInsets.all(20.0);
  static const EdgeInsets emailButton =
      EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0);

  // Mobile-optimized for emails
  static const EdgeInsets mobilePadding =
      EdgeInsets.symmetric(horizontal: 16.0);
  static const EdgeInsets mobileSection = EdgeInsets.symmetric(vertical: 20.0);

  // Common email layout spacings
  static const EdgeInsets headerPadding =
      EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 16.0);
  static const EdgeInsets bodyPadding =
      EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 24.0);
  static const EdgeInsets footerPadding =
      EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 20.0);
}
