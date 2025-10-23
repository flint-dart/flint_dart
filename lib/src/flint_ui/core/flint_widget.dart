// lib/flint_ui/core/flint_widget.dart

import 'dart:math';

import 'package:flint_dart/src/flint_ui/core/flint_script.dart';

abstract class FlintWidget {
  final String id;
  final FlintScript? script;

  static final _rng = Random();

  FlintWidget({String? id, this.script}) : id = id ?? _generateId();

  static String _generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final randomString =
        List.generate(6, (_) => chars[_rng.nextInt(chars.length)]).join();
    return 'flint-${randomString}';
  }

  /// Render to HTML (for emails, web)
  String toHtml();

  /// Render to plain text (fallback, CLI, etc.)
  String toText();

  /// Render to intermediate JSON (for APIs, mobile apps, etc.)
  Map<String, dynamic> toJson();

  /// Build the widget template - MUST be implemented by subclasses
  FlintWidget buildTemplate();

  /// Render attached script to HTML attributes
  String renderScriptAttributes() {
    final attrs = <String>['id="$id"']; // ✅ Always include ID

    if (script != null) {
      final data = script!.toJson();
      data.forEach((key, value) {
        attrs.add('data-flint-$key=\'${_encodeJson(value)}\'');
      });
    }

    return attrs.join(' ');
  }

  String _encodeJson(dynamic value) {
    return value is String ? value : value.toString();
  }
}
