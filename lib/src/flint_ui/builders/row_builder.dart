// lib/flint_ui/builders/row_builder.dart

import '../core/edge_insets.dart';
import '../core/flint_widget.dart';
import '../core/style.dart';
import '../widgets/widget.dart';

class FlintRowBuilder {
  /// Create a responsive row that stacks on mobile
  static FlintFlexRow responsive({
    required List<FlintWidget> children,
    List<int>? columnWidths,
    double gap = 16.0,
    bool mobileStack = true,
  }) {
    return FlintFlexRow(
      children: children,
      columnWidths: columnWidths,
      gap: gap,
      mobileStack: mobileStack,
    );
  }

  /// Create a row with equal width columns
  static FlintRow equalWidth({
    required List<FlintWidget> children,
    double gap = 16.0,
  }) {
    return FlintRow(
      children: children,
      gap: gap,
    );
  }

  /// Create a row with specific column widths
  static FlintRow customWidth({
    required List<FlintWidget> children,
    required List<int> columnWidths,
    double gap = 16.0,
  }) {
    return FlintRow(
      children: children,
      columnWidths: columnWidths,
      gap: gap,
    );
  }

  /// Create a feature row with icons and text
  static FlintRow features({
    required List<FeatureItem> features,
    int columns = 3,
    double gap = 20.0,
  }) {
    final featureWidgets = features.map((feature) {
      return FlintBox(
        padding: EdgeInsets.all(16),
        children: [
          FlintText(
            feature.icon,
            style: TextStyle(fontSize: 32),
            align: TextAlign.center,
          ),
          FlintBox(
            margin: EdgeInsets.only(top: 12),
            children: [
              FlintText(
                feature.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: '#1a1a1a',
                ),
                align: TextAlign.center,
              ),
            ],
          ),
          FlintBox(
            margin: EdgeInsets.only(top: 8),
            children: [
              FlintText(
                feature.description,
                style: TextStyle(
                  fontSize: 12,
                  color: '#666666',
                  // lineHeight: 1.5,
                ),
                align: TextAlign.center,
              ),
            ],
          ),
        ],
      );
    }).toList();

    return FlintRow(
      children: featureWidgets,
      gap: gap,
    );
  }
}

class FeatureItem {
  final String icon;
  final String title;
  final String description;

  FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
