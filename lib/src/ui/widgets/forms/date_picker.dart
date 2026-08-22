import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import '../actions/button.dart';
import '../shared/theme.dart';
import 'controllers.dart';
import 'field_helpers.dart';
import 'validation.dart';
import 'package:universal_web/web.dart' as web;

/// Preset options for quick date selection.
class DatePreset {
  final String label;
  final String date;

  const DatePreset({required this.label, required this.date});
}

/// Preset options for quick date range selection.
class DateRangePreset {
  final String label;
  final String startDate;
  final String endDate;

  const DateRangePreset({
    required this.label,
    required this.startDate,
    required this.endDate,
  });

  static DateRangePreset today() {
    final now = DateTime.now();
    final dateStr = _formatDate(now);
    return DateRangePreset(
      label: 'Today',
      startDate: dateStr,
      endDate: dateStr,
    );
  }

  static DateRangePreset yesterday() {
    final yest = DateTime.now().subtract(const Duration(days: 1));
    final dateStr = _formatDate(yest);
    return DateRangePreset(
      label: 'Yesterday',
      startDate: dateStr,
      endDate: dateStr,
    );
  }

  static DateRangePreset last7Days() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 6));
    return DateRangePreset(
      label: 'Last 7 Days',
      startDate: _formatDate(start),
      endDate: _formatDate(now),
    );
  }

  static DateRangePreset last30Days() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 29));
    return DateRangePreset(
      label: 'Last 30 Days',
      startDate: _formatDate(start),
      endDate: _formatDate(now),
    );
  }

  static DateRangePreset thisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);
    return DateRangePreset(
      label: 'This Month',
      startDate: _formatDate(start),
      endDate: _formatDate(end),
    );
  }
}

String _formatDate(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Interactive date input field component with quick preset support.
class DatePicker extends FlintElement {
  /// Creates a date picker field.
  DatePicker({
    String? label,
    String? name,
    TextEditingController? controller,
    String? value,
    String? min,
    String? max,
    String? placeholder,
    List<DatePreset>? presets,
    bool required = false,
    bool disabled = false,
    bool readonly = false,
    InputVariant variant = InputVariant.outline,
    ComponentSize size = ComponentSize.md,
    String? error,
    FormErrors? errors,
    String? helpText,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> inputProps = const {},
    Map<String, Object?> style = const {},
    Map<String, Object?> inputStyle = const {},
    DartStyle? dartStyle,
    DartStyle? inputDartStyle,
    void Function(Object event)? onChanged,
    void Function(String date)? onDateSelected,
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
           value: controller?.text ?? value,
           min: min,
           max: max,
           placeholder: placeholder,
           presets: presets,
           required: required,
           disabled: disabled,
           readonly: readonly,
           variant: variant,
           size: size,
           error: resolveFieldError(name: name, error: error, errors: errors),
           helpText: helpText,
           inputProps: inputProps,
           inputStyle: inputStyle,
           inputDartStyle: inputDartStyle,
           onChanged: _controlledOnChanged(controller, onChanged, onDateSelected),
         ),
       );

  static void Function(Object event)? _controlledOnChanged(
    TextEditingController? controller,
    void Function(Object event)? onChanged,
    void Function(String date)? onDateSelected,
  ) {
    if (controller == null && onDateSelected == null && onChanged == null) {
      return null;
    }

    return (event) {
      String val = '';
      if (event is web.Event) {
        final target = event.target;
        if (target is web.HTMLInputElement) {
          val = target.value;
          if (controller != null) {
            controller.text = val;
          }
        }
      }
      onDateSelected?.call(val);
      onChanged?.call(event);
    };
  }

  static List<FlintNode> _children({
    required String? label,
    required String? name,
    required String? value,
    required String? min,
    required String? max,
    required String? placeholder,
    required List<DatePreset>? presets,
    required bool required,
    required bool disabled,
    required bool readonly,
    required InputVariant variant,
    required ComponentSize size,
    required String? error,
    required String? helpText,
    required Map<String, Object?> inputProps,
    required Map<String, Object?> inputStyle,
    required DartStyle? inputDartStyle,
    required void Function(Object event)? onChanged,
  }) {
    final id = fieldId('date-picker', name, inputProps);
    final ariaDescribedBy = describedBy(
      id: id,
      helpText: helpText,
      error: error,
      describedBy: inputProps['aria-describedby']?.toString(),
    );

    final mergedInputStyle = mergeStyles(
      inputBaseStyle,
      _variantStyle(variant, error != null),
      _sizeStyle(size),
      inputStyle,
      inputDartStyle?.toMap() ?? const {},
    );

    return [
      if (label != null)
        fieldLabel(id: id, label: label, required: required),
      FlintElement(
        'div',
        props: {'style': {'display': 'flex', 'flex-direction': 'column', 'gap': '8px'}},
        children: [
          FlintElement(
            'input',
            props: controlProps(
              props: {
                ...inputProps,
                'type': 'date',
                if (value != null) 'value': value,
                if (min != null) 'min': min,
                if (max != null) 'max': max,
                if (placeholder != null) 'placeholder': placeholder,
                if (readonly) 'readonly': true,
                'style': mergedInputStyle,
                if (onChanged != null) 'change': onChanged,
                if (onChanged != null) 'input': onChanged,
              },
              id: id,
              name: name,
              required: required,
              disabled: disabled,
              error: error,
              describedBy: ariaDescribedBy,
            ),
          ),
          if (presets != null && presets.isNotEmpty)
            FlintElement(
              'div',
              props: {'style': {'display': 'flex', 'flex-wrap': 'wrap', 'gap': '6px'}},
              children: presets.map((p) {
                return Button(
                  child: FlintText(p.label),
                  variant: ButtonVariant.ghost,
                  size: ComponentSize.sm,
                  onPressed: (e) {
                    onChanged?.call(e);
                  },
                );
              }).toList(),
            ),
        ],
      ),
      ...fieldMessages(id: id, helpText: helpText, error: error),
    ];
  }

  static Map<String, Object?> _variantStyle(
    InputVariant variant,
    bool hasError,
  ) {
    if (hasError) {
      return {
        'border-color': '#fda29b',
        'box-shadow': '0 0 0 4px #fee4e2',
      };
    }

    switch (variant) {
      case InputVariant.outline:
        return {'border': '1px solid #d0d5dd'};
      case InputVariant.soft:
        return {'border': '1px solid transparent', 'background': '#f9fafb'};
      case InputVariant.ghost:
        return {'border': 'none', 'background': 'transparent'};
    }
  }

  static Map<String, Object?> _sizeStyle(ComponentSize size) {
    switch (size) {
      case ComponentSize.xs:
        return {'min-height': '30px', 'font-size': '12px', 'padding': '4px 8px'};
      case ComponentSize.sm:
        return {'min-height': '34px', 'font-size': '13px', 'padding': '6px 10px'};
      case ComponentSize.md:
        return {'min-height': '40px', 'font-size': '14px', 'padding': '8px 12px'};
      case ComponentSize.lg:
        return {'min-height': '46px', 'font-size': '15px', 'padding': '10px 14px'};
    }
  }
}

/// Interactive date range picker component with start/end fields and preset bar.
class DateRangePicker extends FlintElement {
  /// Creates a date range picker component.
  DateRangePicker({
    String? label,
    String? startName,
    String? endName,
    String? startDate,
    String? endDate,
    String? min,
    String? max,
    List<DateRangePreset>? presets,
    bool required = false,
    bool disabled = false,
    InputVariant variant = InputVariant.outline,
    ComponentSize size = ComponentSize.md,
    String? error,
    FormErrors? errors,
    String? helpText,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
    void Function(String startDate, String endDate)? onRangeChanged,
    void Function(Object event)? onChanged,
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
           startName: startName ?? 'start_date',
           endName: endName ?? 'end_date',
           startDate: startDate,
           endDate: endDate,
           min: min,
           max: max,
           presets: presets ?? [
             DateRangePreset.today(),
             DateRangePreset.yesterday(),
             DateRangePreset.last7Days(),
             DateRangePreset.last30Days(),
             DateRangePreset.thisMonth(),
           ],
           required: required,
           disabled: disabled,
           variant: variant,
           size: size,
           error: resolveFieldError(name: startName, error: error, errors: errors),
           helpText: helpText,
           onRangeChanged: onRangeChanged,
           onChanged: onChanged,
         ),
       );

  static List<FlintNode> _children({
    required String? label,
    required String startName,
    required String endName,
    required String? startDate,
    required String? endDate,
    required String? min,
    required String? max,
    required List<DateRangePreset> presets,
    required bool required,
    required bool disabled,
    required InputVariant variant,
    required ComponentSize size,
    required String? error,
    required String? helpText,
    required void Function(String startDate, String endDate)? onRangeChanged,
    required void Function(Object event)? onChanged,
  }) {
    final id = fieldId('date-range-picker', startName, {});

    return [
      if (label != null)
        fieldLabel(id: id, label: label, required: required),
      FlintElement(
        'div',
        props: {
          'style': {
            'display': 'flex',
            'flex-direction': 'column',
            'gap': '10px',
            'background': '#f8fafc',
            'border': '1px solid #e2e8f0',
            'border-radius': '10px',
            'padding': '12px',
          },
        },
        children: [
          FlintElement(
            'div',
            props: {
              'style': {
                'display': 'grid',
                'grid-template-columns': '1fr auto 1fr',
                'align-items': 'center',
                'gap': '8px',
              },
            },
            children: [
              DatePicker(
                name: startName,
                value: startDate,
                min: min,
                max: endDate ?? max,
                disabled: disabled,
                variant: variant,
                size: size,
                placeholder: 'Start date',
                onDateSelected: (val) {
                  onRangeChanged?.call(val, endDate ?? '');
                },
                onChanged: onChanged,
              ),
              FlintElement(
                'span',
                props: {
                  'style': {
                    'color': '#64748b',
                    'font-weight': 600,
                    'font-size': '14px',
                  },
                },
                children: const [FlintText('to')],
              ),
              DatePicker(
                name: endName,
                value: endDate,
                min: startDate ?? min,
                max: max,
                disabled: disabled,
                variant: variant,
                size: size,
                placeholder: 'End date',
                onDateSelected: (val) {
                  onRangeChanged?.call(startDate ?? '', val);
                },
                onChanged: onChanged,
              ),
            ],
          ),
          if (presets.isNotEmpty)
            FlintElement(
              'div',
              props: {
                'style': {
                  'display': 'flex',
                  'flex-wrap': 'wrap',
                  'gap': '6px',
                  'border-top': '1px solid #e2e8f0',
                  'padding-top': '8px',
                },
              },
              children: presets.map((p) {
                return Button(
                  child: FlintText(p.label),
                  variant: ButtonVariant.outline,
                  size: ComponentSize.xs,
                  onPressed: (e) {
                    onRangeChanged?.call(p.startDate, p.endDate);
                    onChanged?.call(e);
                  },
                );
              }).toList(),
            ),
        ],
      ),
      ...fieldMessages(id: id, helpText: helpText, error: error),
    ];
  }
}
