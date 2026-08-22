import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import 'switch.dart';

/// A settings-style row with descriptive text and a trailing switch.
class SwitchRow extends FlintElement {
  /// Creates a switch row for preference and settings screens.
  SwitchRow({
    required String label,
    String? name,
    String? description,
    bool checked = false,
    bool disabled = false,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
    void Function(Object event)? onChanged,
  }) : super(
         'div',
         props: mergeComponentProps(
           props,
           className: className,
           defaultStyle: _switchRowStyle,
           dartStyle: dartStyle,
           style: style,
         ),
         children: [
           FlintElement(
             'div',
             props: const {
               'style': {'min-width': 0},
             },
             children: [
               FlintElement(
                 'span',
                 props: const {'style': _switchRowLabelStyle},
                 children: [FlintText(label)],
               ),
               if (description != null && description.trim().isNotEmpty)
                 FlintElement(
                   'span',
                   props: const {'style': _switchRowDescriptionStyle},
                   children: [FlintText(description)],
                 ),
             ],
           ),
           Switch(
             name: name ?? label.toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
             checked: checked,
             disabled: disabled,
             onChanged: onChanged,
             inputProps: {'aria-label': label},
             dartStyle: const DartStyle(width: SizeValue.auto),
           ),
         ],
       );
}

const _switchRowStyle = {
  'min-height': '48px',
  'display': 'flex',
  'align-items': 'center',
  'justify-content': 'space-between',
  'gap': '12px',
  'padding': '10px 12px',
  'border': '1px solid var(--color-border, #e4e7ec)',
  'border-radius': '8px',
  'background': 'var(--color-surface, #ffffff)',
  'color': 'var(--color-text, #101828)',
};

const _switchRowLabelStyle = {
  'display': 'block',
  'font-size': '13px',
  'font-weight': 700,
  'line-height': 1.35,
};

const _switchRowDescriptionStyle = {
  'display': 'block',
  'margin-top': '2px',
  'font-size': '12px',
  'line-height': 1.4,
  'color': 'var(--color-muted, #667085)',
};
