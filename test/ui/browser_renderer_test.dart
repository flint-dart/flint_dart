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

    test('controlled select applies its value after options render', () async {
      final host = web.document.createElement('div');
      web.document.body?.appendChild(host);
      addTearDown(() => host.remove());

      final component = _ControlledSelectComponent();
      final root = createRootForElement(host);
      root.render(component);
      await _flushRender();

      final select = host.querySelector('select') as web.HTMLSelectElement;
      expect(select.value, 'starter');

      select.value = 'pro';
      select.dispatchEvent(web.Event('change'));
      await _flushRender();

      final updatedSelect =
          host.querySelector('select') as web.HTMLSelectElement;
      expect(component.value, 'pro');
      expect(updatedSelect.value, 'pro');
    });

    test('cleans up extra SSR sibling nodes on hydration', () async {
      final host = web.document.createElement('div');
      web.document.body?.appendChild(host);
      addTearDown(() => host.remove());

      // Simulate SSR having rendered multiple children into the host:
      // Child 0: a <style> tag
      final ssrStyle = web.document.createElement('style');
      ssrStyle.textContent = '.flint-ssr { color: red; }';
      host.appendChild(ssrStyle);

      // Child 1: the server-rendered HTML markup
      final ssrMarkup = web.document.createElement('div');
      ssrMarkup.textContent = 'SSR Content';
      host.appendChild(ssrMarkup);

      expect(host.childNodes.length, 2);

      // Client mounts and hydrates
      final root = createRootForElement(host);
      root.render(div(children: ['Client Content']));
      await _flushRender();

      // Host must only contain the freshly rendered client DOM, NOT the leftover SSR nodes
      expect(host.childNodes.length, 1);
      expect(host.textContent, 'Client Content');
      expect(host.textContent, isNot(contains('SSR Content')));
    });

    test('preserves existing DOM element reference across setState rerenders',
        () async {
      final host = web.document.createElement('div');
      web.document.body?.appendChild(host);
      addTearDown(() => host.remove());

      final component = _PreservedDomComponent();
      final root = createRootForElement(host);
      root.render(component);
      await _flushRender();

      final containerBefore = host.querySelector('.container-box');
      expect(containerBefore, isNotNull);
      expect(containerBefore?.textContent, contains('Count: 0'));

      component.increment();
      await _flushRender();

      final containerAfter = host.querySelector('.container-box');
      expect(containerAfter, isNotNull);
      expect(containerAfter?.textContent, contains('Count: 1'));
      // The DOM node must be identical (not destroyed and re-created)
      expect(identical(containerBefore, containerAfter), isTrue);
    });

    test('supports zero-argument event handlers without type error', () async {
      final host = web.document.createElement('div');
      web.document.body?.appendChild(host);
      addTearDown(() => host.remove());

      var clicked = false;
      final root = createRootForElement(host);
      root.render(
        div(
          children: [
            button(
              props: {
                'id': 'test-btn',
                'onClick': () {
                  clicked = true;
                },
              },
              children: ['Click me'],
            ),
          ],
        ),
      );
      await _flushRender();

      final btn = host.querySelector('#test-btn') as web.HTMLButtonElement;
      btn.click();
      expect(clicked, isTrue);
    });
  });
}

class _PreservedDomComponent extends StatefulComponent {
  int count = 0;

  void increment() {
    setState(() {
      count++;
    });
  }

  @override
  View build() {
    return div(
      props: {'className': 'container-box'},
      children: [
        span(children: ['Count: $count']),
      ],
    );
  }
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

class _ControlledSelectComponent extends StatefulComponent {
  String value = 'starter';

  @override
  Object? build() {
    return Select(
      value: value,
      options: const [
        SelectOption(label: 'Starter', value: 'starter'),
        SelectOption(label: 'Pro', value: 'pro'),
      ],
      onChanged: (event) {
        setState(() => value = FlintEvent.value(event));
      },
    );
  }
}
