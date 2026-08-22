import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import '../actions/button.dart';
import '../actions/button_group.dart';
import '../shared/theme.dart';
import 'modal.dart';

/// Confirmation dialog for dangerous or deliberate user actions.
class ConfirmAction extends FlintElement {
  /// Creates a confirmation modal controlled by [open].
  ConfirmAction({
    required bool open,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool danger = false,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
    void Function(Object event)? onConfirm,
    void Function(Object event)? onCancel,
  }) : super(
         'div',
         props: mergeComponentProps(
           props,
           className: className,
           dartStyle: dartStyle,
           style: style,
         ),
         children: [
           Modal(
             open: open,
             title: title,
             child: message,
             onClose: onCancel,
             actions: ButtonGroup(
               children: [
                 Button(
                   child: cancelLabel,
                   variant: ButtonVariant.outline,
                   tone: Tone.neutral,
                   onPressed: onCancel,
                 ),
                 Button(
                   child: confirmLabel,
                   tone: danger ? Tone.danger : Tone.primary,
                   onPressed: onConfirm,
                 ),
               ],
             ),
           ),
         ],
       );
}
