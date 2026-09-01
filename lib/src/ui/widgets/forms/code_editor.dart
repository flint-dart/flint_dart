import 'package:universal_web/web.dart' as web;

import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import '../shared/theme.dart';
import 'controllers.dart';
import 'field_helpers.dart';
import 'validation.dart';

/// A lightweight, theme-aware plain-text code editor.
///
/// [CodeEditor] provides a monospace textarea, synchronized line numbers, and
/// controller support without rebuilding its parent for every keystroke. It is
/// intended for configuration files, source snippets, JSON, YAML, and similar
/// plain-text content. It does not provide syntax highlighting.
class CodeEditor extends FlintElement {
  /// Creates a plain-text code editor.
  CodeEditor({
    String? label,
    String? name,
    TextEditingController? controller,
    Object? value,
    String? placeholder,
    bool required = false,
    bool disabled = false,
    bool readonly = false,
    bool showLineNumbers = true,
    Object height = 320,
    InputVariant variant = InputVariant.outline,
    ComponentSize size = ComponentSize.md,
    String? error,
    FormErrors? errors,
    String? helpText,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> editorProps = const {},
    Map<String, Object?> style = const {},
    Map<String, Object?> editorStyle = const {},
    DartStyle? dartStyle,
    DartStyle? editorDartStyle,
    void Function(String value)? onChanged,
  }) : super(
          'div',
          props: fieldWrapperProps(
            props: props,
            className: className,
            dartStyle: dartStyle,
            style: style,
          ),
          children: _children(
            label: label,
            name: name,
            controller: controller,
            value: controller?.text ?? value,
            placeholder: placeholder,
            required: required,
            disabled: disabled,
            readonly: readonly,
            showLineNumbers: showLineNumbers,
            height: height,
            variant: variant,
            size: size,
            error: resolveFieldError(name: name, error: error, errors: errors),
            helpText: helpText,
            editorProps: editorProps,
            editorStyle: editorStyle,
            editorDartStyle: editorDartStyle,
            onChanged: onChanged,
          ),
        );

  static List<FlintNode> _children({
    required String? label,
    required String? name,
    required TextEditingController? controller,
    required Object? value,
    required String? placeholder,
    required bool required,
    required bool disabled,
    required bool readonly,
    required bool showLineNumbers,
    required Object height,
    required InputVariant variant,
    required ComponentSize size,
    required String? error,
    required String? helpText,
    required Map<String, Object?> editorProps,
    required Map<String, Object?> editorStyle,
    required DartStyle? editorDartStyle,
    required void Function(String value)? onChanged,
  }) {
    final id = fieldId('code-editor', name, editorProps);
    final gutterId = '$id-line-numbers';
    final text = value?.toString() ?? '';
    final ariaDescribedBy = describedBy(
      id: id,
      helpText: helpText,
      error: error,
      describedBy: editorProps['aria-describedby']?.toString(),
    );

    void syncGutter(web.HTMLTextAreaElement target) {
      if (!showLineNumbers) return;
      final gutter = web.document.getElementById(gutterId);
      if (gutter == null) return;
      gutter
        ..textContent = _lineNumbers(target.value)
        ..scrollTop = target.scrollTop;
    }

    void handleInput(Object event) {
      final target = event is web.Event ? event.target : null;
      if (target is! web.HTMLTextAreaElement) return;
      controller?.text = target.value;
      syncGutter(target);
      onChanged?.call(target.value);
    }

    void handleScroll(Object event) {
      final target = event is web.Event ? event.target : null;
      if (target is! web.HTMLTextAreaElement || !showLineNumbers) return;
      final gutter = web.document.getElementById(gutterId);
      if (gutter != null) gutter.scrollTop = target.scrollTop;
    }

    final editor = FlintElement(
      'textarea',
      props: mergeComponentProps(
        {
          ...controlProps(
            props: editorProps,
            id: id,
            name: name,
            required: required,
            disabled: disabled,
            error: error,
            describedBy: ariaDescribedBy,
          ),
          if (readonly) 'readonly': true,
          'value': text,
          if (placeholder != null) 'placeholder': placeholder,
          'wrap': 'off',
          'spellcheck': 'false',
          'autocapitalize': 'off',
          'autocomplete': 'off',
          'onInput': handleInput,
          if (showLineNumbers) 'onScroll': handleScroll,
        },
        dartStyle: inputComponentStyle(
          variant: variant,
          size: size,
          disabled: disabled,
          invalid: error != null && error.isNotEmpty,
        )
            .merge(
              DartStyle(
                width: SizeValue.full,
                height: SizeValue.full,
                minWidth: 0,
                minHeight: 0,
                flex: 1,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                radius: 0,
                border: Border.none,
                background: ThemeToken.color(
                  'inputSurface',
                  fallback: '#ffffff',
                ).toCss(),
                color: ThemeToken.color(
                  'inputText',
                  fallback: '#101828',
                ).toCss(),
                fontFamily: ThemeToken.font(
                  'mono',
                  fallback: FontFamily.monospace,
                ).toCss(),
                fontSize: 13,
                lineHeight: 1.6,
                resize: Resize.none,
              ),
            )
            .merge(editorDartStyle),
        style: {'tab-size': 2, ...editorStyle},
      ),
    );

    final surface = FlintElement(
      'div',
      props: mergeComponentProps(
        {'role': 'group', 'aria-label': label ?? 'Code editor'},
        dartStyle: DartStyle(
          display: Display.flex,
          alignItems: AlignItems.stretch,
          width: SizeValue.full,
          height: height,
          overflow: Overflow.hidden,
          radius: ThemeToken.radius('md', fallback: '8px').toCss(),
          border: Border(
            color: ThemeToken.color(
              'inputBorder',
              fallback: '#d0d5dd',
            ).toCss(),
          ),
          background: ThemeToken.color(
            'inputSurface',
            fallback: '#ffffff',
          ).toCss(),
          opacity: disabled ? 0.7 : null,
        ),
      ),
      children: [
        if (showLineNumbers)
          FlintElement(
            'div',
            props: mergeComponentProps(
              {
                'id': gutterId,
                'aria-hidden': 'true',
                'style': {'user-select': 'none'},
              },
              dartStyle: DartStyle(
                width: 52,
                height: SizeValue.full,
                flexShrink: 0,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 10,
                ),
                overflow: Overflow.hidden,
                background: ThemeToken.color(
                  'surfaceMuted',
                  fallback: '#f8fafc',
                ).toCss(),
                borderRight: Border(
                  color: ThemeToken.color(
                    'inputBorder',
                    fallback: '#d0d5dd',
                  ).toCss(),
                ),
                color: ThemeToken.color(
                  'muted',
                  fallback: '#667085',
                ).toCss(),
                fontFamily: ThemeToken.font(
                  'mono',
                  fallback: FontFamily.monospace,
                ).toCss(),
                fontSize: 13,
                lineHeight: 1.6,
                textAlign: TextAlign.right,
                whiteSpace: WhiteSpace.pre,
              ),
            ),
            children: [FlintText(_lineNumbers(text))],
          ),
        editor,
      ],
    );

    return [
      if (label != null) fieldLabel(id: id, label: label, required: required),
      surface,
      ...fieldMessages(id: id, helpText: helpText, error: error),
    ];
  }

  static String _lineNumbers(String value) {
    final count = '\n'.allMatches(value).length + 1;
    return List.generate(count, (index) => '${index + 1}').join('\n');
  }
}
