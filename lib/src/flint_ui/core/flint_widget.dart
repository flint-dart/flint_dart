// lib/flint_ui/core/flint_widget.dart

import 'dart:math';
import 'package:flint_dart/src/flint_ui/core/flint_script.dart';

abstract class FlintWidget {
  final String id;
  final FlintScript? script;

  // ---------- Alpine-style directives ----------
  final String? xData;
  final String? xInit;
  final String? xShow;
  final Map<String, String> xBind;
  final Map<String, String> xOn;
  final String? xText;
  final String? xHtml;
  final String? xModel;
  final String? xModelable;
  final String? xFor;
  final String? xTransition;
  final String? xEffect;
  final bool? xIgnore;
  final String? xRef;
  final bool? xCloak;
  final String? xTeleport;
  final bool? xIf;
  final String? xId;

  Map<String, String> get directives => {
        if (xData != null) 'x-data': xData!,
        if (xInit != null) 'x-init': xInit!,
        if (xShow != null) 'x-show': xShow!,
        if (xText != null) 'x-text': xText!,
        if (xHtml != null) 'x-html': xHtml!,
        if (xModel != null) 'x-model': xModel!,
        if (xModelable != null) 'x-modelable': xModelable!,
        if (xFor != null) 'x-for': xFor!,
        if (xTransition != null) 'x-transition': xTransition!,
        if (xEffect != null) 'x-effect': xEffect!,
        if (xIgnore == true) 'x-ignore': '',
        if (xRef != null) 'x-ref': xRef!,
        if (xCloak == true) 'x-cloak': '',
        if (xTeleport != null) 'x-teleport': xTeleport!,
        if (xIf == true) 'x-if': '',
        if (xId != null) 'x-id': xId!,
        ...xBind.map((k, v) => MapEntry('x-bind:$k', v)),
        ...xOn.map((k, v) => MapEntry('x-on:$k', v)),
      };

  static final _rng = Random();

  FlintWidget({
    String? id,
    this.script,
    this.xData,
    this.xInit,
    this.xShow,
    Map<String, String>? xBind,
    Map<String, String>? xOn,
    this.xText,
    this.xHtml,
    this.xModel,
    this.xModelable,
    this.xFor,
    this.xTransition,
    this.xEffect,
    this.xIgnore,
    this.xRef,
    this.xCloak,
    this.xTeleport,
    this.xIf,
    this.xId,
  })  : xBind = xBind ?? {},
        xOn = xOn ?? {},
        id = id ?? _generateId();

  static String _generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final randomString =
        List.generate(6, (_) => chars[_rng.nextInt(chars.length)]).join();
    return 'flint-$randomString';
  }

  /// Render to HTML (for emails, web)
  String toHtml();

  /// Render to plain text (fallback, CLI, etc.)
  String toText();

  /// Render to intermediate JSON (for APIs, mobile apps, etc.)
  Map<String, dynamic> toJson();

  /// Build the widget template - MUST be implemented by subclasses
  FlintWidget buildTemplate();

  /// ---------------- Helper ----------------
  /// Converts ID + directives + optional style to HTML attributes
  String renderAttributes({String? style}) {
    final attrs = <String>[];

    // Always include ID
    if (id.isNotEmpty) attrs.add('id="$id"');

    // Include all Alpine-style directives
    directives.forEach((key, value) {
      if (value.isEmpty) {
        attrs.add(key);
      } else {
        attrs.add('$key="$value"');
      }
    });

    // Include inline style if provided
    if (style != null && style.isNotEmpty) {
      attrs.add('style="$style"');
    }

    return attrs.join(' ');
  }

  /// Render attached script to HTML attributes
  String renderScriptAttributes() {
    final attrs = <String>[];

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
