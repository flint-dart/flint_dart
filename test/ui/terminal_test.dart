import 'package:flint_dart/flint_ui_core.dart';
import 'package:test/test.dart';

void main() {
  test('Terminal renders an accessible viewport and toolbar controls', () {
    final terminal = Terminal(
      websocketUrl: '/ws/terminal',
      title: 'Application terminal',
      height: 420,
    );

    final root = terminal.build() as FlintElement;
    final toolbar = root.children[0] as FlintElement;
    final viewport = root.children[1] as FlintElement;
    final texts = _texts(root);

    expect(toolbar.tag, 'div');
    expect(texts,
        containsAll(['Application terminal', 'Reconnect', 'Clear', 'Copy']));
    expect(viewport.props['role'], 'application');
    expect(viewport.props['aria-label'],
        'Application terminal interactive terminal');
    expect(viewport.props['style'], containsPair('height', '420px'));
  });

  test('TerminalController delegates commands to its mounted terminal',
      () async {
    final controller = TerminalController();
    final owner = Object();
    final calls = <String>[];

    controller.attach(
      owner: owner,
      connect: () => calls.add('connect'),
      reconnect: () => calls.add('reconnect'),
      disconnect: () => calls.add('disconnect'),
      clear: () => calls.add('clear'),
      focus: () => calls.add('focus'),
      write: (data) => calls.add('write:$data'),
      send: (data) {
        calls.add('send:$data');
        return true;
      },
      copySelection: () async {
        calls.add('copy');
        return true;
      },
    );

    controller
      ..connect()
      ..reconnect()
      ..clear()
      ..focus()
      ..write('local')
      ..disconnect();
    expect(controller.send('ls\n'), true);
    expect(await controller.copySelection(), true);
    controller.updateConnectionState(owner, TerminalConnectionState.connected);

    expect(controller.isAttached, true);
    expect(controller.connectionState, TerminalConnectionState.connected);
    expect(
      calls,
      [
        'connect',
        'reconnect',
        'clear',
        'focus',
        'write:local',
        'disconnect',
        'send:ls\n',
        'copy'
      ],
    );

    controller.detach(owner);
    expect(controller.isAttached, false);
    expect(controller.send('ignored'), false);
  });
}

List<String> _texts(Object? node) {
  final values = <String>[];

  void walk(Object? current) {
    if (current is FlintText) {
      values.add(current.value);
    } else if (current is FlintElement) {
      for (final child in current.children) {
        walk(child);
      }
    } else if (current is FlintComponent) {
      walk(current.build());
    }
  }

  walk(node);
  return values;
}
