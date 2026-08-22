import 'package:flint_dart/flint_ui_core.dart';
import 'package:test/test.dart';

void main() {
  group('overlay components', () {
    test(
      'Modal and Drawer unmount when closed and expose dialog semantics when open',
      () {
        final modal = Modal(open: false, title: 'Edit user', child: 'Body');
        final closedModal = modal.build() as FlintFragment;
        expect(closedModal.children, isEmpty);

        final openModal = Modal(open: true, title: 'Edit user', child: 'Body');
        final modalElement = openModal.build() as FlintElement;
        expect(modalElement.props['role'], 'dialog');
        expect(modalElement.props.containsKey('hidden'), false);
        expect(modalElement.props['aria-modal'], 'true');

        final closedDrawer = Drawer(open: false, title: 'Details');
        final closedDrawerFragment = closedDrawer.build() as FlintFragment;
        expect(closedDrawerFragment.children, isEmpty);

        final drawer = Drawer(open: true, title: 'Details', side: 'left');
        final drawerElement = drawer.build() as FlintElement;
        expect(drawerElement.tag, 'aside');
        expect(drawerElement.props['role'], 'dialog');
        expect(drawerElement.props.containsKey('hidden'), false);
        expect(drawerElement.props['style'], containsPair('left', 0));
      },
    );

    test('Tooltip and Popover render trigger plus overlay content', () {
      final tooltip = Tooltip(
        content: 'More info',
        child: Button(child: 'Info'),
      );
      expect(tooltip.children.first, isA<Button>());
      final tip = tooltip.children.last as FlintElement;
      expect(tip.props['role'], 'tooltip');

      final popover = Popover(
        trigger: Button(child: 'Open'),
        open: false,
        child: Text('Filters'),
      );
      final closedPopover = popover.build() as FlintElement;
      expect(closedPopover.children, hasLength(1));

      final openPopover = Popover(
        trigger: Button(child: 'Open'),
        open: true,
        child: Text('Filters'),
      );
      final openPopoverElement = openPopover.build() as FlintElement;
      final panel = openPopoverElement.children.last as FlintElement;
      expect(panel.props['role'], 'dialog');
      expect(panel.props.containsKey('hidden'), false);
    });

    test('Toast and Skeleton render feedback surfaces', () {
      final toast = Toast(title: 'Saved', message: 'Settings updated');
      expect(toast.props['role'], 'status');
      expect(toast.children.first, isA<FlintElement>());

      final skeleton = Skeleton(lines: 3, width: 120);
      expect(skeleton.children, hasLength(3));
      final line = skeleton.children.first as FlintElement;
      expect(line.props['aria-hidden'], 'true');
      expect(line.props['style'], containsPair('width', '120px'));
    });

    test('ConfirmAction wraps confirmation modal and actions', () {
      final confirm = ConfirmAction(
        open: true,
        title: 'Delete user',
        message: 'This cannot be undone.',
        danger: true,
        onConfirm: (_) {},
        onCancel: (_) {},
      );

      expect(confirm.children.single, isA<Modal>());
      final modal = confirm.children.single as Modal;
      final modalElement = modal.build() as FlintElement;
      final section = modalElement.children.single as FlintElement;
      final footer = section.children.last as FlintElement;
      expect(footer.children.single, isA<ButtonGroup>());
    });
  });
}
