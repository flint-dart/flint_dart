import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:universal_web/web.dart' as web;

import 'component.dart';
import 'node.dart';
import 'widgets/primitives/canvas.dart';
import 'widgets/primitives/media_preview.dart';
import 'widgets/primitives/three_scene.dart';

final _elementListeners = Expando<Map<String, Function>>();

/// Browser DOM root that renders Flint nodes into a host element.
class FlintRoot {
  /// Host element that receives rendered DOM nodes.
  final web.Element host;
  FlintNode? _node;
  FlintNode? _renderedNode;
  Map<String, _ComponentMount> _componentSlots = {};
  final _registeredStyleIds = <String>{};
  bool _renderQueued = false;
  bool _mounted = false;

  /// Creates a root renderer for [host].
  FlintRoot(this.host);

  /// Renders [node] into the host element.
  void render(Object? node) {
    _node = _normalize(node);
    _scheduleRender();
  }

  void _scheduleRender() {
    if (_renderQueued) return;
    _renderQueued = true;
    scheduleMicrotask(() {
      _renderQueued = false;
      _paint();
    });
  }

  void _paint() {
    final node = _node;
    if (node == null) return;

    final activeControl = _ActiveControl.capture(host);
    final previousSlots = _componentSlots;
    final nextSlots = <String, _ComponentMount>{};

    final oldRendered = _renderedNode;
    final firstChild =
        host.childNodes.length > 0 ? host.childNodes.item(0) : null;

    if (oldRendered != null && firstChild != null && _mounted) {
      _reconcileNode(
        parentDom: host,
        existingDom: firstChild,
        oldNode: oldRendered,
        newNode: node,
        path: '0',
        previousSlots: previousSlots,
        nextSlots: nextSlots,
      );
      while (host.childNodes.length > 1) {
        final last = host.childNodes.item(host.childNodes.length - 1);
        if (last != null) {
          host.removeChild(last);
        } else {
          break;
        }
      }
    } else {
      final nextDom = _createDom(node, '0', previousSlots, nextSlots);
      if (firstChild != null) {
        host.replaceChild(nextDom, firstChild);
        while (host.childNodes.length > 1) {
          final last = host.childNodes.item(host.childNodes.length - 1);
          if (last != null) {
            host.removeChild(last);
          } else {
            break;
          }
        }
      } else {
        host.appendChild(nextDom);
      }
    }

    _renderedNode = node;
    _restoreActiveControl(activeControl, host);
    for (final entry in previousSlots.entries) {
      if (!nextSlots.containsKey(entry.key)) {
        _unmountComponentTree(entry.value);
      }
    }
    _componentSlots = nextSlots;
    _mounted = true;
  }

  web.Node _createDom(
    FlintNode node,
    String path,
    Map<String, _ComponentMount> previousSlots,
    Map<String, _ComponentMount> nextSlots,
  ) {
    return switch (node) {
      FlintText(:final value) => web.document.createTextNode(value),
      FlintRawHtml(:final value, :final trusted) => _createRawHtml(
          value,
          trusted,
        ),
      FlintFragment(:final children) => _createFragment(
          children,
          path,
          previousSlots,
          nextSlots,
        ),
      FlintElement(:final tag, :final props, :final children) => _createElement(
          tag,
          props,
          children,
          path,
          previousSlots,
          nextSlots,
        ),
      FlintComponent() => _createComponent(
          node,
          path,
          previousSlots,
          nextSlots,
        ),
      FlintComponentNode(:final component) => _createComponent(
          component,
          path,
          previousSlots,
          nextSlots,
        ),
      _ => throw UnsupportedError(
          'Unsupported FlintNode type: ${node.runtimeType}',
        ),
    };
  }

  web.Node _createRawHtml(String value, bool trusted) {
    if (!trusted) return web.document.createTextNode(value);

    final template =
        web.document.createElement('template') as web.HTMLTemplateElement;
    template.innerHTML = value.toJS;
    return template.content.cloneNode(true);
  }

  web.DocumentFragment _createFragment(
    List<FlintNode> children,
    String path,
    Map<String, _ComponentMount> previousSlots,
    Map<String, _ComponentMount> nextSlots,
  ) {
    final fragment = web.document.createDocumentFragment();
    for (var i = 0; i < children.length; i++) {
      fragment.appendChild(
        _createDom(children[i], '$path.$i', previousSlots, nextSlots),
      );
    }
    return fragment;
  }

  web.Element _createElement(
    String tag,
    Map<String, Object?> props,
    List<FlintNode> children,
    String path,
    Map<String, _ComponentMount> previousSlots,
    Map<String, _ComponentMount> nextSlots,
  ) {
    final element = _createDomElement(tag);

    // For <select>, defer applying 'value' until after child <option> elements
    // are appended — setting element.value before options exist is a browser no-op.
    final deferredSelectValue =
        (tag == 'select') ? props['value']?.toString() : null;

    _applyProps(element, props);

    for (var i = 0; i < children.length; i++) {
      element.appendChild(
        _createDom(children[i], '$path.$i', previousSlots, nextSlots),
      );
    }

    // Apply deferred select value now that <option> children are in the DOM.
    if (deferredSelectValue != null && element is web.HTMLSelectElement) {
      element.value = deferredSelectValue;
    }

    return element;
  }

  web.Element _createDomElement(String tag) {
    if (_svgTags.contains(tag)) {
      return web.document.createElementNS('http://www.w3.org/2000/svg', tag);
    }

    return web.document.createElement(tag);
  }

  web.Node _createComponent(
    FlintComponent component,
    String path,
    Map<String, _ComponentMount> previousSlots,
    Map<String, _ComponentMount> nextSlots,
  ) {
    final previous = previousSlots[path];
    final hasExisting = previous != null &&
        previous.component.runtimeType == component.runtimeType &&
        previous.component.preserveState &&
        component.preserveState;
    final mount = hasExisting
        ? previous
        : _ComponentMount(
            component,
            web.document.createElement('flint-component'),
          );
    if (previous != null && !hasExisting) {
      _unmountComponentTree(previous);
    }
    nextSlots[path] = mount;

    var shouldRender = true;
    if (hasExisting) {
      shouldRender = mount.component.shouldUpdate(component);
      mount.component.updateFrom(component);
      mount.component.initProps();
    }
    mount.component.attach(() => _scheduleComponentRender(mount));
    if (shouldRender) {
      _renderComponent(mount);
    }

    if (_mounted && hasExisting) {
      mount.component.didUpdate();
    } else {
      scheduleMicrotask(mount.component.didMount);
    }

    return mount.boundary;
  }

  void _scheduleComponentRender(_ComponentMount mount) {
    if (mount.renderQueued) return;
    mount.renderQueued = true;
    scheduleMicrotask(() {
      mount.renderQueued = false;
      _renderComponent(mount);
      if (mount.mounted) {
        mount.component.didUpdate();
      }
    });
  }

  void _renderComponent(_ComponentMount mount) {
    final previousSlots = mount.childSlots;
    final nextSlots = <String, _ComponentMount>{};
    final activeControl = _ActiveControl.capture(mount.boundary);

    mount.component.ensureInitialized();
    mount.boundary.setAttribute('style', 'display: contents;');

    final nextNode = _normalize(mount.component.build());
    final oldNode = mount.renderedNode;
    final firstChild = mount.boundary.childNodes.length > 0
        ? mount.boundary.childNodes.item(0)
        : null;

    if (oldNode is FlintFragment &&
        nextNode is FlintFragment &&
        mount.mounted) {
      _reconcileChildren(
        mount.boundary,
        oldNode.children,
        nextNode.children,
        'c',
        previousSlots,
        nextSlots,
      );
    } else if (oldNode != null && firstChild != null && mount.mounted) {
      _reconcileNode(
        parentDom: mount.boundary,
        existingDom: firstChild,
        oldNode: oldNode,
        newNode: nextNode,
        path: 'c',
        previousSlots: previousSlots,
        nextSlots: nextSlots,
      );
      while (mount.boundary.childNodes.length > 1) {
        final last = mount.boundary.childNodes.item(
          mount.boundary.childNodes.length - 1,
        );
        if (last != null) {
          mount.boundary.removeChild(last);
        } else {
          break;
        }
      }
    } else {
      mount.boundary.textContent = '';
      mount.boundary.appendChild(
        _createDom(
          nextNode,
          'c',
          previousSlots,
          nextSlots,
        ),
      );
    }

    mount.renderedNode = nextNode;
    _restoreActiveControl(activeControl, mount.boundary);

    for (final entry in previousSlots.entries) {
      if (!nextSlots.containsKey(entry.key)) {
        _unmountComponentTree(entry.value);
      }
    }

    mount.childSlots = nextSlots;
    mount.mounted = true;
  }

  web.Node _reconcileNode({
    required web.Node parentDom,
    required web.Node existingDom,
    required FlintNode oldNode,
    required FlintNode newNode,
    required String path,
    required Map<String, _ComponentMount> previousSlots,
    required Map<String, _ComponentMount> nextSlots,
  }) {
    // 1. Text nodes
    if (oldNode is FlintText && newNode is FlintText) {
      if (existingDom is web.Text) {
        if (oldNode.value != newNode.value) {
          existingDom.textContent = newNode.value;
        }
        return existingDom;
      }
    }

    // 2. Elements with matching tag
    if (oldNode is FlintElement && newNode is FlintElement) {
      if (existingDom is web.Element &&
          existingDom.tagName.toLowerCase() == newNode.tag.toLowerCase()) {
        _patchProps(existingDom, oldNode.props, newNode.props);
        _reconcileChildren(
          existingDom,
          oldNode.children,
          newNode.children,
          path,
          previousSlots,
          nextSlots,
        );
        if (newNode.tag == 'select' && existingDom is web.HTMLSelectElement) {
          final selectVal = newNode.props['value']?.toString();
          if (selectVal != null && existingDom.value != selectVal) {
            existingDom.value = selectVal;
          }
        }
        return existingDom;
      }
    }

    // 3. Components
    final oldComp = _extractComponent(oldNode);
    final newComp = _extractComponent(newNode);
    if (oldComp != null && newComp != null) {
      return _createComponent(newComp, path, previousSlots, nextSlots);
    }

    // 4. Fallback: Types or tags do not match -> create fresh DOM and replace
    final nextDom = _createDom(newNode, path, previousSlots, nextSlots);
    parentDom.replaceChild(nextDom, existingDom);
    return nextDom;
  }

  FlintComponent? _extractComponent(FlintNode node) {
    if (node is FlintComponent) return node;
    if (node is FlintComponentNode) return node.component;
    return null;
  }

  void _reconcileChildren(
    web.Element parentDom,
    List<FlintNode> oldChildren,
    List<FlintNode> newChildren,
    String path,
    Map<String, _ComponentMount> previousSlots,
    Map<String, _ComponentMount> nextSlots,
  ) {
    final commonLength = math.min(oldChildren.length, newChildren.length);
    final domChildCount = parentDom.childNodes.length;

    for (var i = 0; i < commonLength; i++) {
      final childPath = '$path.$i';
      if (i < domChildCount) {
        final childDom = parentDom.childNodes.item(i);
        if (childDom != null) {
          _reconcileNode(
            parentDom: parentDom,
            existingDom: childDom,
            oldNode: oldChildren[i],
            newNode: newChildren[i],
            path: childPath,
            previousSlots: previousSlots,
            nextSlots: nextSlots,
          );
        }
      } else {
        parentDom.appendChild(
          _createDom(newChildren[i], childPath, previousSlots, nextSlots),
        );
      }
    }

    if (newChildren.length > oldChildren.length) {
      for (var i = oldChildren.length; i < newChildren.length; i++) {
        final childPath = '$path.$i';
        parentDom.appendChild(
          _createDom(newChildren[i], childPath, previousSlots, nextSlots),
        );
      }
    } else if (oldChildren.length > newChildren.length) {
      while (parentDom.childNodes.length > newChildren.length) {
        final last =
            parentDom.childNodes.item(parentDom.childNodes.length - 1);
        if (last != null) {
          parentDom.removeChild(last);
        } else {
          break;
        }
      }
    }
  }

  void _patchProps(
    web.Element element,
    Map<String, Object?> oldProps,
    Map<String, Object?> newProps,
  ) {
    for (final entry in oldProps.entries) {
      final name = entry.key;
      final oldValue = entry.value;
      if (oldValue == null || oldValue == false) continue;
      if (!newProps.containsKey(name) ||
          newProps[name] == null ||
          newProps[name] == false) {
        _removeProp(element, name, oldValue);
      }
    }

    for (final entry in newProps.entries) {
      final name = entry.key;
      final newValue = entry.value;
      if (newValue == null || newValue == false) continue;
      final oldValue = oldProps[name];
      if (oldValue != newValue) {
        _applySingleProp(element, name, newValue);
      }
    }
  }

  void _removeProp(web.Element element, String name, Object? oldValue) {
    if (name == '_flintStyleCss' ||
        name == '_flintMediaController' ||
        name == '_flintCanvasController' ||
        name == '_flintThreeSceneController') {
      return;
    }
    if (name == 'className') {
      element.className = '';
      return;
    }
    if (name == 'style') {
      element.removeAttribute('style');
      return;
    }
    if (name.startsWith('on')) {
      _elementListeners[element]?.remove(name.substring(2).toLowerCase());
      return;
    }
    if (name == 'value') {
      if (element is web.HTMLInputElement) element.value = '';
      if (element is web.HTMLTextAreaElement) element.value = '';
      if (element is web.HTMLSelectElement) element.value = '';
      return;
    }
    if (name == 'checked' && element is web.HTMLInputElement) {
      element.checked = false;
      element.removeAttribute('checked');
      return;
    }
    element.removeAttribute(name);
  }

  void _applySingleProp(web.Element element, String name, Object value) {
    if (name == '_flintStyleCss') {
      _registerScopedStyle(value.toString());
      return;
    }

    if (name == '_flintMediaController') {
      if (value is MediaElementController) {
        value.attachTo(element);
      }
      return;
    }

    if (name == '_flintCanvasController') {
      if (value is CanvasController) {
        value.attachTo(element);
      }
      return;
    }

    if (name == '_flintThreeSceneController') {
      if (value is ThreeSceneController) {
        value.attachTo(element);
      }
      return;
    }

    if (name == 'className') {
      element.className = value.toString();
      return;
    }

    if (name == 'style') {
      _applyStyle(element, value);
      return;
    }

    if (_applyFormProperty(element, name, value)) {
      return;
    }

    if (_applyMediaProperty(element, name, value)) {
      return;
    }

    if (name.startsWith('on') && value is Function) {
      _listen(element, name.substring(2).toLowerCase(), value);
      return;
    }

    if (value == true) {
      element.setAttribute(name, '');
      return;
    }

    element.setAttribute(name, value.toString());
  }

  void _applyProps(web.Element element, Map<String, Object?> props) {
    props.forEach((name, value) {
      if (value == null || value == false) return;
      _applySingleProp(element, name, value);
    });
  }

  void _restoreActiveControl(_ActiveControl? activeControl, web.Element scope) {
    if (activeControl == null) return;

    final restored = activeControl.restore(scope);
    if (!restored) {
      scheduleMicrotask(() => activeControl.restore(scope));
    }
  }

  void _unmountComponentTree(_ComponentMount mount) {
    for (final child in mount.childSlots.values) {
      _unmountComponentTree(child);
    }
    mount.component.willUnmount();
  }

  bool _applyFormProperty(web.Element element, String name, Object value) {
    if (name == 'value') {
      final nextValue = value.toString();
      if (element is web.HTMLInputElement) {
        if (element.value != nextValue) {
          element.value = nextValue;
        }
        return true;
      }
      if (element is web.HTMLTextAreaElement) {
        if (element.value != nextValue) {
          element.value = nextValue;
        }
        return true;
      }
      if (element is web.HTMLSelectElement) {
        if (element.value != nextValue) {
          element.value = nextValue;
        }
        return true;
      }
    }

    if (name == 'checked' && element is web.HTMLInputElement) {
      element.checked = value == true;
      if (value == true) {
        element.setAttribute(name, '');
      }
      return true;
    }

    return false;
  }

  bool _applyMediaProperty(web.Element element, String name, Object value) {
    if (element is web.HTMLMediaElement) {
      if (name == 'muted') {
        element.muted = value == true;
        if (value == true) element.setAttribute(name, '');
        return true;
      }
      if (name == 'controls') {
        element.controls = value == true;
        if (value == true) element.setAttribute(name, '');
        return true;
      }
      if (name == 'autoplay') {
        element.autoplay = value == true;
        if (value == true) element.setAttribute(name, '');
        return true;
      }
      if (name == 'loop') {
        element.loop = value == true;
        if (value == true) element.setAttribute(name, '');
        return true;
      }
    }

    if (name == 'playsinline' && element is web.HTMLVideoElement) {
      element.playsInline = value == true;
      if (value == true) element.setAttribute(name, '');
      return true;
    }

    return false;
  }

  void _registerScopedStyle(String cssText) {
    if (cssText.trim().isEmpty) return;

    final id = 'flint-style-${cssText.hashCode}';
    if (_registeredStyleIds.contains(id)) return;
    _registeredStyleIds.add(id);

    final head = web.document.querySelector('head');
    if (head == null) return;

    final element = web.document.createElement('style');
    element.setAttribute('data-flint-style-id', id);
    element.textContent = cssText;
    head.appendChild(element);
  }

  void _applyStyle(web.Element element, Object? value) {
    if (value is String) {
      element.setAttribute('style', value);
      return;
    }

    if (value is Map<String, Object?>) {
      final style = value.entries
          .where((entry) => entry.value != null)
          .map((entry) => '${entry.key}: ${entry.value}')
          .join('; ');
      element.setAttribute('style', style);
    }
  }

  void _listen(web.Element element, String eventName, Function handler) {
    var listeners = _elementListeners[element];
    if (listeners == null) {
      listeners = <String, Function>{};
      _elementListeners[element] = listeners;
    }

    final hadListener = listeners.containsKey(eventName);
    listeners[eventName] = handler;

    if (!hadListener) {
      element.addEventListener(
        eventName,
        ((web.Event event) {
          final current = _elementListeners[element]?[eventName];
          if (current != null) {
            if (current is void Function()) {
              current();
            } else {
              current(event);
            }
          }
        }).toJS,
      );
    }
  }

  FlintNode _normalize(Object? node) {
    if (node is FlintNode) return node;
    if (node is FlintComponent) return FlintComponentNode(node);
    return FlintText(node?.toString() ?? '');
  }
}

const _svgTags = {
  'svg',
  'path',
  'line',
  'polyline',
  'polygon',
  'circle',
  'rect',
  'ellipse',
  'title',
  'g',
};

/// Creates a root renderer for the first element matching [selector].
FlintRoot createRoot(String selector) {
  final element = web.document.querySelector(selector);

  if (element == null) {
    throw StateError('No element found for selector "$selector".');
  }

  return FlintRoot(element);
}

/// Creates a root renderer for an existing browser [element].
FlintRoot createRootForElement(web.Element element) => FlintRoot(element);

class _ComponentMount {
  final FlintComponent component;
  final web.Element boundary;
  FlintNode? renderedNode;
  Map<String, _ComponentMount> childSlots = {};
  bool renderQueued = false;
  bool mounted = false;

  _ComponentMount(this.component, this.boundary);
}

class _ActiveControl {
  _ActiveControl({
    required this.tag,
    required this.value,
    this.id,
    this.name,
    this.type,
    this.domPath,
    this.selectionStart,
    this.selectionEnd,
  });

  final String tag;
  final String value;
  final String? id;
  final String? name;
  final String? type;
  final List<int>? domPath;
  final int? selectionStart;
  final int? selectionEnd;

  static _ActiveControl? capture(web.Element scope) {
    final active = web.document.activeElement;
    if (active == null || !scope.contains(active)) return null;

    final tagName = active.tagName.toLowerCase();
    if (tagName == 'input') {
      final input = active as web.HTMLInputElement;
      return _ActiveControl(
        tag: 'input',
        value: input.value,
        id: input.id.isEmpty ? null : input.id,
        name: input.name.isEmpty ? null : input.name,
        type: input.type.isEmpty ? null : input.type,
        domPath: _pathFrom(scope, active),
        selectionStart: input.selectionStart,
        selectionEnd: input.selectionEnd,
      );
    }

    if (tagName == 'textarea') {
      final textarea = active as web.HTMLTextAreaElement;
      return _ActiveControl(
        tag: 'textarea',
        value: textarea.value,
        id: textarea.id.isEmpty ? null : textarea.id,
        name: textarea.name.isEmpty ? null : textarea.name,
        domPath: _pathFrom(scope, active),
        selectionStart: textarea.selectionStart,
        selectionEnd: textarea.selectionEnd,
      );
    }

    return null;
  }

  bool restore(web.Element scope) {
    final control = _find(scope);
    if (control == null) return false;

    final tagName = control.tagName.toLowerCase();
    if (tagName == 'input') {
      final input = control as web.HTMLInputElement;
      if (input.value != value) {
        input.value = value;
      }
      input.focus();
      _restoreSelection(input);
      return true;
    }

    if (tagName == 'textarea') {
      final textarea = control as web.HTMLTextAreaElement;
      if (textarea.value != value) {
        textarea.value = value;
      }
      textarea.focus();
      _restoreSelection(textarea);
      return true;
    }

    return false;
  }

  web.Element? _find(web.Element scope) {
    final byPath = _findByPath(scope);
    if (byPath != null) return byPath;

    if (id != null) {
      final byId = web.document.getElementById(id!);
      if (byId != null && scope.contains(byId) && _matches(byId)) {
        return byId;
      }
    }

    final controls = scope.querySelectorAll(tag);
    for (var i = 0; i < controls.length; i++) {
      final candidate = controls.item(i);
      if (candidate is web.Element && _matches(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  web.Element? _findByPath(web.Element scope) {
    final path = domPath;
    if (path == null || path.isEmpty) return null;

    web.Node node = scope;
    for (final index in path) {
      final children = node.childNodes;
      if (index < 0 || index >= children.length) return null;
      final child = children.item(index);
      if (child == null) return null;
      node = child;
    }

    if (node is web.Element && _matches(node, allowUnkeyed: true)) return node;
    return null;
  }

  bool _matches(web.Element element, {bool allowUnkeyed = false}) {
    final elemTag = element.tagName.toLowerCase();
    if (elemTag != tag) return false;

    if (elemTag == 'input') {
      final input = element as web.HTMLInputElement;
      if (type != null && input.type != type) return false;
      if (name != null && input.name == name) return true;
      if (id != null && input.id == id) return true;
      return allowUnkeyed && name == null && id == null;
    }

    if (elemTag == 'textarea') {
      final textarea = element as web.HTMLTextAreaElement;
      if (name != null && textarea.name == name) return true;
      if (id != null && textarea.id == id) return true;
      return allowUnkeyed && name == null && id == null;
    }

    return false;
  }

  void _restoreSelection(web.Element control) {
    final start = selectionStart;
    final end = selectionEnd;
    if (start == null || end == null) return;

    try {
      final elemTag = control.tagName.toLowerCase();
      if (elemTag == 'input') {
        (control as web.HTMLInputElement).setSelectionRange(start, end);
      } else if (elemTag == 'textarea') {
        (control as web.HTMLTextAreaElement).setSelectionRange(start, end);
      }
    } catch (_) {
      // Some input types, such as number/date, do not support text selection.
    }
  }

  static List<int>? _pathFrom(web.Element scope, web.Node node) {
    final path = <int>[];
    web.Node? current = node;

    while (current != null && current != scope) {
      final parent = current.parentNode;
      if (parent == null) return null;

      final siblings = parent.childNodes;
      var index = -1;
      for (var i = 0; i < siblings.length; i++) {
        if (siblings.item(i) == current) {
          index = i;
          break;
        }
      }
      if (index == -1) return null;

      path.insert(0, index);
      current = parent;
    }

    if (current != scope) return null;
    return path;
  }
}
