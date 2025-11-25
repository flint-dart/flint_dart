// lib/flint_ui/builders/column_builder.dart

import 'package:flint_dart/flint_ui.dart';

class ColumnBuilder {
  /// Create a basic column with consistent spacing
  static Column basic({
    required List<FlintWidget> children,
    double gap = 16.0,
    Alignment alignment = Alignment.left,
  }) {
    return Column(
      children: children,
      gap: gap,
      alignment: alignment,
    );
  }

  /// Create a centered column
  static Column centered({
    required List<FlintWidget> children,
    double gap = 16.0,
  }) {
    return Column(
      children: children,
      gap: gap,
      alignment: Alignment.center,
    );
  }

  /// Create a card-like column with background and padding
  static Column card({
    required List<FlintWidget> children,
    double gap = 16.0,
    String backgroundColor = '#ffffff',
    double borderRadius = 8.0,
  }) {
    return Column(
      children: children,
      gap: gap,
      padding: EdgeInsets.all(20),
      backgroundColor: backgroundColor,
      border: BoxBorder.all(color: '#e0e0e0'),
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }

  /// Create a column for form fields
  static Column form({
    required List<FlintWidget> children,
    double gap = 12.0,
  }) {
    return Column(
      children: children,
      gap: gap,
      alignment: Alignment.left,
    );
  }

  /// Create a column for a list of items
  static Column list({
    required List<ListItem> items,
    double gap = 8.0,
    String bullet = '•',
  }) {
    final children = items.map((item) {
      return Column(
        children: [
          Text('$bullet ', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(item.text),
        ],
      );
    }).toList();

    return Column(
      children: children,
      gap: gap,
    );
  }

  /// Create a column with alternating background colors
  static Column striped({
    required List<FlintWidget> children,
    String oddColor = '#ffffff',
    String evenColor = '#f8f9fa',
    double gap = 0,
  }) {
    final styledChildren = <FlintWidget>[];

    for (int i = 0; i < children.length; i++) {
      final backgroundColor = i.isEven ? evenColor : oddColor;
      final child = children[i];

      if (child is Container) {
        // If it's already a box, update its background
        // styledChildren.add(child.copyWith(
        //   backgroundColor: backgroundColor,
        //   padding: child.padding ??
        //       EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        // ));
      } else {
        // Wrap in a box with background
        styledChildren.add(Container(
          children: [child],
          backgroundColor: backgroundColor,
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ));
      }
    }

    return Column(
      children: styledChildren,
      gap: gap,
    );
  }
}

class ListItem {
  final String text;
  final String? url;

  ListItem(this.text, {this.url});
}
