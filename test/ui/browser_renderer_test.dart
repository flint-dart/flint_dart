@TestOn('browser')
library;

import 'dart:async';

import 'package:flint_dart/flint_ui.dart';
import 'package:test/test.dart';
import 'package:universal_web/web.dart' as web;

void main() {
  group('browser renderer', () {
    test(
      'restores caret on the active repeated input after rerender',
      () async {
        final host = web.document.createElement('div');
        web.document.body?.appendChild(host);
        addTearDown(() => host.remove());

        final root = createRootForElement(host);
        root.render(_repeatedFields('Alpha', 'Bravo'));
        await _flushRender();

        final inputs = host.querySelectorAll('input');
        final second = inputs.item(1) as web.HTMLInputElement;
        second.focus();
        await _flushRender();
        second.setSelectionRange(2, 2);
        expect(second.selectionStart, 2);

        root.render(_repeatedFields('Alpha', 'Bravo updated'));
        await _flushRender();

        final updatedInputs = host.querySelectorAll('input');
        final updatedSecond = updatedInputs.item(1) as web.HTMLInputElement;

        expect(web.document.activeElement, updatedSecond);
        expect(updatedSecond.selectionStart, 2);
        expect(updatedSecond.selectionEnd, 2);
      },
    );

    test('restores caret on an unkeyed active input after rerender', () async {
      final host = web.document.createElement('div');
      web.document.body?.appendChild(host);
      addTearDown(() => host.remove());

      final root = createRootForElement(host);
      root.render(
        div(
          children: [
            h('input', props: {'value': 'Alpha'}),
          ],
        ),
      );
      await _flushRender();

      final input = host.querySelector('input') as web.HTMLInputElement;
      input.focus();
      input.setSelectionRange(3, 3);

      root.render(
        div(
          children: [
            h('input', props: {'value': 'Alpha typed'}),
          ],
        ),
      );
      await _flushRender();

      final updatedInput = host.querySelector('input') as web.HTMLInputElement;
      expect(web.document.activeElement, updatedInput);
      expect(updatedInput.selectionStart, 3);
      expect(updatedInput.selectionEnd, 3);
    });

    test('setState can update component fields without rendering', () async {
      final host = web.document.createElement('div');
      web.document.body?.appendChild(host);
      addTearDown(() => host.remove());

      final component = _SilentStateComponent();
      final root = createRootForElement(host);
      root.render(component);
      await _flushRender();

      component.updateSilently('typed');
      await _flushRender();

      expect(component.value, 'typed');
      expect(component.builds, 1);
      expect(host.textContent, 'initial');
    });

    test(
      'controlled input keeps caret after setState from onChanged',
      () async {
        final host = web.document.createElement('div');
        web.document.body?.appendChild(host);
        addTearDown(() => host.remove());

        final component = _ControlledInputComponent();
        final root = createRootForElement(host);
        root.render(component);
        await _flushRender();

        final input = host.querySelector('input') as web.HTMLInputElement;
        input.focus();
        input.value = 'abXcd';
        input.setSelectionRange(3, 3);
        input.dispatchEvent(web.Event('input'));
        await _flushRender();

        final updatedInput =
            host.querySelector('input') as web.HTMLInputElement;
        expect(component.value, 'abXcd');
        expect(web.document.activeElement, updatedInput);
        expect(updatedInput.value, 'abXcd');
        expect(updatedInput.selectionStart, 3);
        expect(updatedInput.selectionEnd, 3);
      },
    );
  });
}

FlintElement _repeatedFields(String first, String second) {
  return div(
    children: [
      TextField(name: 'variant-title', value: first),
      TextField(name: 'variant-title', value: second),
    ],
  );
}

Future<void> _flushRender() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _SilentStateComponent extends StatefulComponent {
  String value = 'initial';
  int builds = 0;

  void updateSilently(String nextValue) {
    setState(() => value = nextValue, render: false);
  }

  @override
  Object? build() {
    builds++;
    return value == 'initial' ? text('initial') : text('updated');
  }
}

class _ControlledInputComponent extends StatefulComponent {
  String value = 'abcd';

  @override
  Object? build() {
    return TextField(
      value: value,
      onChanged: (event) {
        setState(() => value = FlintEvent.value(event));
      },
    );
  }
}
