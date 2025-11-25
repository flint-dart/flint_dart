// lib/flint_ui/builders/row_builder.dart

import '../core/edge_insets.dart';
import '../core/flint_widget.dart';
import '../core/style.dart';
import '../widgets/widget.dart';

class RowBuilder {
  /// Create a responsive row that stacks on mobile
  static Row responsive({
    required List<FlintWidget> children,
    List<int>? columnWidths,
    double gap = 16.0,
    bool mobileStack = true,
  }) {
    return Row(
      children: children,
      // columnWidths: columnWidths,
      gap: gap,
    );
  }

  /// Create a row with equal width columns
  static Row equalWidth({
    required List<FlintWidget> children,
    double gap = 16.0,
  }) {
    return Row(
      children: children,
      gap: gap,
    );
  }

  /// Create a row with specific column widths
  static Row customWidth({
    required List<FlintWidget> children,
    required List<int> columnWidths,
    double gap = 16.0,
  }) {
    return Row(
      children: children,
      columnWidths: columnWidths,
      gap: gap,
    );
  }

  /// Create a feature row with icons and text
  static Row features({
    required List<FeatureItem> features,
    int columns = 3,
    double gap = 20.0,
  }) {
    final featureWidgets = features.map((feature) {
      return Container(
        padding: EdgeInsets.all(16),
        children: [
          Text(
            feature.icon,
            style: TextStyle(fontSize: 32),
            align: TextAlign.center,
          ),
          Container(
            margin: EdgeInsets.only(top: 12),
            children: [
              Text(
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
          Container(
            margin: EdgeInsets.only(top: 8),
            children: [
              Text(
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

    return Row(
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
