import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';

import 'package:universal_web/web.dart' as web;

import '../../component.dart';
import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import '../actions/button.dart';
import '../shared/theme.dart';
import 'terminal_stub.dart' as stub;

export 'terminal_stub.dart'
    show TerminalConnectionState, TerminalController, TerminalTheme;

/// A lifecycle-managed, interactive xterm.js terminal using WebSockets.
class Terminal extends StatefulComponent {
  /// Creates an interactive WebSocket terminal.
  Terminal({
    required this.websocketUrl,
    this.controller,
    this.title = 'Terminal',
    this.height = 400,
    this.showToolbar = true,
    this.autoConnect = true,
    this.autoReconnect = true,
    this.reconnectDelay = const Duration(seconds: 2),
    this.sendResizeMessages = true,
    this.fontSize = 13,
    this.fontFamily =
        'ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace',
    this.scrollback = 5000,
    this.theme = const stub.TerminalTheme(),
    this.connectingMessage = 'Connecting to terminal...',
    this.scriptUrl = 'https://cdn.jsdelivr.net/npm/xterm@5.3.0/lib/xterm.js',
    this.stylesheetUrl =
        'https://cdn.jsdelivr.net/npm/xterm@5.3.0/css/xterm.css',
    this.className,
    this.props = const {},
    this.style = const {},
    this.dartStyle,
    this.onConnectionStateChanged,
    this.onInput,
    this.onOutput,
    this.onResize,
    this.onError,
  });

  /// WebSocket URL receiving keystrokes and producing terminal output.
  String websocketUrl;

  /// Optional imperative terminal controller.
  stub.TerminalController? controller;

  /// Toolbar title.
  String title;

  /// Terminal viewport height.
  Object height;

  /// Whether reconnect, clear, and copy actions are shown.
  bool showToolbar;

  /// Whether to connect after the browser component mounts.
  bool autoConnect;

  /// Whether unexpected socket closures should be retried.
  bool autoReconnect;

  /// Delay before reconnecting a dropped socket.
  Duration reconnectDelay;

  /// Whether terminal size changes are sent as JSON resize envelopes.
  bool sendResizeMessages;

  /// Terminal font size in pixels.
  int fontSize;

  /// Terminal monospace font stack.
  String fontFamily;

  /// Maximum number of retained terminal lines.
  int scrollback;

  /// Light and dark xterm.js colors.
  stub.TerminalTheme theme;

  /// Text written before the first connection attempt.
  String connectingMessage;

  /// xterm.js browser script URL.
  String scriptUrl;

  /// xterm.js stylesheet URL.
  String stylesheetUrl;

  /// Optional wrapper class name.
  String? className;

  /// Additional wrapper HTML properties.
  Map<String, Object?> props;

  /// Additional wrapper inline styles.
  Map<String, Object?> style;

  /// Additional typed wrapper styles.
  DartStyle? dartStyle;

  /// Called whenever the WebSocket connection state changes.
  void Function(stub.TerminalConnectionState state)? onConnectionStateChanged;

  /// Called after keyboard input is sent.
  void Function(String data)? onInput;

  /// Called when terminal output is received.
  void Function(String data)? onOutput;

  /// Called when the terminal calculates a new character grid size.
  void Function(int columns, int rows)? onResize;

  /// Called when asset loading or the WebSocket reports an error.
  void Function(Object error)? onError;

  static int _nextId = 0;
  static Future<void>? _assetLoad;

  late final String _instanceId = 'flint-terminal-${_nextId++}';
  JSObject? _xterm;
  JSObject? _dataSubscription;
  web.WebSocket? _socket;
  web.ResizeObserver? _resizeObserver;
  web.MutationObserver? _themeObserver;
  Timer? _reconnectTimer;
  bool _mounted = false;
  bool _requiresRemount = false;
  bool _requiresReconnect = false;
  int _generation = 0;
  int _columns = 80;
  int _rows = 24;
  stub.TerminalConnectionState _connectionState =
      stub.TerminalConnectionState.idle;

  @override
  bool get preserveState => true;

  @override
  bool shouldUpdate(covariant Terminal next) {
    return title != next.title ||
        height.toString() != next.height.toString() ||
        showToolbar != next.showToolbar ||
        className != next.className;
  }

  @override
  void updateFrom(covariant Terminal next) {
    final oldController = controller;
    final endpointChanged = websocketUrl != next.websocketUrl;
    final assetsChanged =
        scriptUrl != next.scriptUrl || stylesheetUrl != next.stylesheetUrl;
    final terminalOptionsChanged = fontSize != next.fontSize ||
        fontFamily != next.fontFamily ||
        scrollback != next.scrollback ||
        !identical(theme, next.theme);
    final structuralChanged = shouldUpdate(next) || assetsChanged;

    websocketUrl = next.websocketUrl;
    controller = next.controller;
    title = next.title;
    height = next.height;
    showToolbar = next.showToolbar;
    autoConnect = next.autoConnect;
    autoReconnect = next.autoReconnect;
    reconnectDelay = next.reconnectDelay;
    sendResizeMessages = next.sendResizeMessages;
    fontSize = next.fontSize;
    fontFamily = next.fontFamily;
    scrollback = next.scrollback;
    theme = next.theme;
    connectingMessage = next.connectingMessage;
    scriptUrl = next.scriptUrl;
    stylesheetUrl = next.stylesheetUrl;
    className = next.className;
    props = next.props;
    style = next.style;
    dartStyle = next.dartStyle;
    onConnectionStateChanged = next.onConnectionStateChanged;
    onInput = next.onInput;
    onOutput = next.onOutput;
    onResize = next.onResize;
    onError = next.onError;

    if (!identical(oldController, controller)) {
      oldController?.detach(this);
      _bindController();
    }
    if (structuralChanged || terminalOptionsChanged) {
      _disposeRuntime();
      _requiresRemount = true;
    } else if (endpointChanged) {
      _requiresReconnect = true;
    }
  }

  @override
  void didMount() {
    _mounted = true;
    _bindController();
    unawaited(_initialize());
  }

  @override
  void didUpdate() {
    if (_requiresRemount) {
      _requiresRemount = false;
      unawaited(_initialize());
      return;
    }
    if (_requiresReconnect) {
      _requiresReconnect = false;
      reconnect();
    }
  }

  @override
  void willUnmount() {
    _mounted = false;
    controller?.detach(this);
    _disposeRuntime();
  }

  void _bindController() {
    controller?.attach(
      owner: this,
      connect: connect,
      reconnect: reconnect,
      disconnect: disconnect,
      clear: clear,
      focus: focus,
      write: write,
      send: send,
      copySelection: copySelection,
    );
    controller?.updateConnectionState(this, _connectionState);
  }

  Future<void> _initialize() async {
    final generation = ++_generation;
    _setConnectionState(stub.TerminalConnectionState.connecting);
    try {
      await _ensureAssets(scriptUrl, stylesheetUrl);
      if (!_mounted || generation != _generation) return;
      final mount = web.document.getElementById('$_instanceId-mount');
      if (mount is! web.HTMLElement) {
        throw StateError('Terminal mount element was not found.');
      }

      mount.textContent = '';
      final constructor = globalContext.getProperty<JSAny?>('Terminal'.toJS);
      if (constructor is! JSFunction) {
        throw StateError('xterm.js did not expose the Terminal constructor.');
      }

      _xterm = constructor.callAsConstructorVarArgs<JSObject>([
        {
          'cursorBlink': true,
          'convertEol': true,
          'fontSize': fontSize,
          'fontFamily': fontFamily,
          'lineHeight': 1.4,
          'scrollback': scrollback,
          'theme': _terminalTheme(),
        }.jsify(),
      ]);
      _callTerminal('open', [mount]);
      final subscription = _callTerminal('onData', [
        ((JSString value) => send(value.toDart)).toJS,
      ]);
      if (subscription is JSObject) _dataSubscription = subscription;

      _resizeObserver = web.ResizeObserver(
        ((JSArray<web.ResizeObserverEntry> _, web.ResizeObserver __) {
          _fitTerminal();
        }).toJS,
      )..observe(mount);
      final documentElement = web.document.documentElement;
      if (documentElement != null) {
        _themeObserver = web.MutationObserver(
          ((JSArray<web.MutationRecord> _, web.MutationObserver __) {
            _applyTerminalTheme();
          }).toJS,
        )..observe(
            documentElement,
            web.MutationObserverInit(attributes: true),
          );
      }
      _fitTerminal();
      focus();
      if (connectingMessage.trim().isNotEmpty) {
        write('\x1b[36m$connectingMessage\x1b[0m\r\n');
      }
      if (autoConnect) {
        connect();
      } else {
        _setConnectionState(stub.TerminalConnectionState.idle);
      }
    } catch (error) {
      if (!_mounted || generation != _generation) return;
      _reportError(error);
    }
  }

  /// Connects the configured WebSocket endpoint.
  void connect() {
    if (!_mounted || _xterm == null) return;
    final current = _socket;
    if (current != null &&
        (current.readyState == web.WebSocket.CONNECTING ||
            current.readyState == web.WebSocket.OPEN)) {
      return;
    }

    _reconnectTimer?.cancel();
    _setConnectionState(stub.TerminalConnectionState.connecting);
    try {
      final socket = web.WebSocket(_absoluteWebSocketUrl(websocketUrl));
      _socket = socket;
      socket.binaryType = 'blob';
      socket.onopen = ((web.Event _) {
        if (!identical(_socket, socket)) return;
        _setConnectionState(stub.TerminalConnectionState.connected);
        write('\x1b[32mConnected.\x1b[0m\r\n');
        _fitTerminal(forceResizeMessage: true);
        focus();
      }).toJS;
      socket.onmessage = ((web.MessageEvent event) {
        if (!identical(_socket, socket)) return;
        final data = event.data;
        if (data is JSString) {
          _handleOutput(data.toDart);
        } else if (data is web.Blob) {
          final reader = web.FileReader();
          reader.onload = ((web.Event _) {
            final result = reader.result;
            if (result is JSString) _handleOutput(result.toDart);
          }).toJS;
          reader.readAsText(data);
        }
      }).toJS;
      socket.onerror = ((web.Event error) {
        if (!identical(_socket, socket)) return;
        onError?.call(error);
        _setConnectionState(stub.TerminalConnectionState.error);
      }).toJS;
      socket.onclose = ((web.CloseEvent event) {
        if (!identical(_socket, socket)) return;
        _socket = null;
        write(
          '\r\n\x1b[31mConnection closed (code ${event.code}).\x1b[0m\r\n',
        );
        if (_mounted && autoReconnect) {
          _scheduleReconnect();
        } else {
          _setConnectionState(stub.TerminalConnectionState.closed);
        }
      }).toJS;
    } catch (error) {
      _reportError(error);
      if (autoReconnect) _scheduleReconnect();
    }
  }

  /// Reopens the terminal WebSocket without rebuilding the component.
  void reconnect() {
    _reconnectTimer?.cancel();
    _closeSocket();
    _setConnectionState(stub.TerminalConnectionState.reconnecting);
    connect();
  }

  /// Closes the terminal WebSocket and stops automatic reconnect attempts.
  void disconnect() {
    _reconnectTimer?.cancel();
    _closeSocket();
    _setConnectionState(stub.TerminalConnectionState.closed);
  }

  /// Clears the visible xterm.js buffer.
  void clear() {
    _callTerminal('clear');
    focus();
  }

  /// Focuses the xterm.js input surface.
  void focus() {
    _callTerminal('focus');
  }

  /// Writes text locally without sending it to the WebSocket.
  void write(String data) {
    _callTerminal('write', [data.toJS]);
  }

  /// Sends raw input to the connected WebSocket.
  bool send(String data) {
    final socket = _socket;
    if (socket == null || socket.readyState != web.WebSocket.OPEN) return false;
    socket.send(data.toJS);
    onInput?.call(data);
    return true;
  }

  /// Copies selected terminal text to the browser clipboard.
  Future<bool> copySelection() async {
    final selected = _callTerminal('getSelection');
    if (selected is! JSString || selected.toDart.isEmpty) return false;
    try {
      await web.window.navigator.clipboard.writeText(selected.toDart).toDart;
      focus();
      return true;
    } catch (error) {
      onError?.call(error);
      return false;
    }
  }

  void _handleOutput(String data) {
    if (_isErrorEnvelope(data)) return;
    write(data);
    onOutput?.call(data);
  }

  bool _isErrorEnvelope(String data) {
    final trimmed = data.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) return false;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map && decoded['error'] != null) {
        final message = decoded['error'].toString();
        write('\r\n\x1b[31mError: $message\x1b[0m\r\n');
        _reportError(message, writeToTerminal: false);
        return true;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  void _fitTerminal({bool forceResizeMessage = false}) {
    final mount = web.document.getElementById('$_instanceId-mount');
    if (mount is! web.HTMLElement || _xterm == null) return;
    final columns =
        max(20, ((mount.clientWidth - 16) / (fontSize * 0.62)).floor());
    final rows = max(5, ((mount.clientHeight - 16) / (fontSize * 1.4)).floor());
    final changed = columns != _columns || rows != _rows;
    if (changed) {
      _columns = columns;
      _rows = rows;
      _callTerminal('resize', [columns.toJS, rows.toJS]);
      onResize?.call(columns, rows);
    }
    if ((changed || forceResizeMessage) && sendResizeMessages) {
      _sendResize(columns, rows);
    }
  }

  void _sendResize(int columns, int rows) {
    final socket = _socket;
    if (socket == null || socket.readyState != web.WebSocket.OPEN) return;
    socket.send(
      jsonEncode({'type': 'resize', 'cols': columns, 'rows': rows}).toJS,
    );
  }

  void _scheduleReconnect() {
    if (!_mounted || !autoReconnect) return;
    _setConnectionState(stub.TerminalConnectionState.reconnecting);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay, connect);
  }

  void _closeSocket() {
    final socket = _socket;
    _socket = null;
    if (socket != null &&
        (socket.readyState == web.WebSocket.CONNECTING ||
            socket.readyState == web.WebSocket.OPEN)) {
      socket.close();
    }
  }

  void _disposeRuntime() {
    _generation++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _closeSocket();
    _resizeObserver?.disconnect();
    _resizeObserver = null;
    _themeObserver?.disconnect();
    _themeObserver = null;
    _disposeJsObject(_dataSubscription);
    _dataSubscription = null;
    _callTerminal('dispose');
    _xterm = null;
  }

  void _setConnectionState(stub.TerminalConnectionState state) {
    _connectionState = state;
    controller?.updateConnectionState(this, state);
    onConnectionStateChanged?.call(state);
    final element = web.document.getElementById('$_instanceId-status');
    if (element is web.HTMLElement) {
      element
        ..textContent = _stateLabel(state)
        ..setAttribute('data-state', state.name);
      element.style.color = _stateColor(state);
    }
  }

  void _reportError(Object error, {bool writeToTerminal = true}) {
    _setConnectionState(stub.TerminalConnectionState.error);
    if (writeToTerminal) {
      write('\r\n\x1b[31mTerminal error: $error\x1b[0m\r\n');
    }
    onError?.call(error);
  }

  Map<String, Object?> _terminalTheme() {
    final mode =
        web.document.documentElement?.getAttribute('data-theme') ?? 'light';
    final dark = mode == 'dark';
    return {
      'background': dark ? theme.darkBackground : theme.lightBackground,
      'foreground': dark ? theme.darkForeground : theme.lightForeground,
      'cursor': dark ? theme.darkCursor : theme.lightCursor,
      'selectionBackground': dark ? theme.darkSelection : theme.lightSelection,
    };
  }

  void _applyTerminalTheme() {
    final terminal = _xterm;
    if (terminal == null) return;
    final options = terminal.getProperty<JSAny?>('options'.toJS);
    if (options is JSObject) {
      options.setProperty('theme'.toJS, _terminalTheme().jsify());
    }
  }

  JSAny? _callTerminal(String method, [List<JSAny?> arguments = const []]) {
    final terminal = _xterm;
    if (terminal == null) return null;
    final function = terminal.getProperty<JSAny?>(method.toJS);
    if (function is! JSFunction) return null;
    return switch (arguments.length) {
      0 => function.callAsFunction(terminal),
      1 => function.callAsFunction(terminal, arguments[0]),
      2 => function.callAsFunction(terminal, arguments[0], arguments[1]),
      _ => throw ArgumentError.value(
          arguments.length,
          'arguments',
          'Terminal method calls support at most two arguments.',
        ),
    };
  }

  void _disposeJsObject(JSObject? value) {
    if (value == null) return;
    final dispose = value.getProperty<JSAny?>('dispose'.toJS);
    if (dispose is JSFunction) dispose.callAsFunction(value);
  }

  String _absoluteWebSocketUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('ws://') || trimmed.startsWith('wss://')) {
      return trimmed;
    }
    final protocol = web.window.location.protocol == 'https:' ? 'wss' : 'ws';
    if (trimmed.startsWith('/')) {
      return '$protocol://${web.window.location.host}$trimmed';
    }
    return '$protocol://${web.window.location.host}/$trimmed';
  }

  static Future<void> _ensureAssets(String scriptUrl, String stylesheetUrl) {
    final terminal = globalContext.getProperty<JSAny?>('Terminal'.toJS);
    if (terminal is JSFunction) return Future<void>.value();
    final existing = _assetLoad;
    if (existing != null) return existing;

    final completer = Completer<void>();
    _assetLoad = completer.future;
    if (web.document.querySelector('link[href="$stylesheetUrl"]') == null) {
      final link = web.document.createElement('link') as web.HTMLLinkElement;
      link
        ..rel = 'stylesheet'
        ..href = stylesheetUrl;
      web.document.head?.appendChild(link);
    }

    final timeout = Timer(const Duration(seconds: 15), () {
      if (completer.isCompleted) return;
      _assetLoad = null;
      completer.completeError(
        TimeoutException(
            'Timed out loading xterm.js.', const Duration(seconds: 15)),
      );
    });
    void complete() {
      if (completer.isCompleted) return;
      timeout.cancel();
      final loaded = globalContext.getProperty<JSAny?>('Terminal'.toJS);
      if (loaded is JSFunction) {
        completer.complete();
      } else {
        _assetLoad = null;
        completer.completeError(StateError('xterm.js failed to initialize.'));
      }
    }

    final existingScript = web.document.querySelector(
      'script[src="$scriptUrl"]',
    );
    if (existingScript is web.HTMLScriptElement) {
      existingScript.addEventListener(
          'load', ((web.Event _) => complete()).toJS);
      existingScript.addEventListener(
        'error',
        ((web.Event error) {
          if (completer.isCompleted) return;
          timeout.cancel();
          _assetLoad = null;
          completer.completeError(error);
        }).toJS,
      );
    } else {
      final script =
          web.document.createElement('script') as web.HTMLScriptElement;
      script
        ..src = scriptUrl
        ..defer = true
        ..onload = ((web.Event _) => complete()).toJS
        ..onerror = ((web.Event error) {
          if (completer.isCompleted) return;
          timeout.cancel();
          _assetLoad = null;
          completer.completeError(error);
        }).toJS;
      web.document.head?.appendChild(script);
    }
    return completer.future;
  }

  String _stateLabel(stub.TerminalConnectionState state) {
    return switch (state) {
      stub.TerminalConnectionState.idle => 'Ready',
      stub.TerminalConnectionState.connecting => 'Connecting...',
      stub.TerminalConnectionState.connected => 'Connected',
      stub.TerminalConnectionState.reconnecting => 'Reconnecting...',
      stub.TerminalConnectionState.error => 'Connection error',
      stub.TerminalConnectionState.closed => 'Disconnected',
    };
  }

  String _stateColor(stub.TerminalConnectionState state) {
    return switch (state) {
      stub.TerminalConnectionState.connected => '#16a34a',
      stub.TerminalConnectionState.error => '#dc2626',
      stub.TerminalConnectionState.connecting ||
      stub.TerminalConnectionState.reconnecting =>
        '#0284c7',
      _ => '#64748b',
    };
  }

  @override
  View build() {
    return FlintElement(
      'div',
      props: mergeComponentProps(
        props,
        className: className,
        dartStyle: const DartStyle(
          display: Display.grid,
          gap: 10,
          width: SizeValue.full,
        ).merge(dartStyle),
        style: style,
      ),
      children: [
        if (showToolbar)
          FlintElement(
            'div',
            props: mergeComponentProps(
              const {},
              dartStyle: const DartStyle(
                display: Display.flex,
                alignItems: AlignItems.center,
                justifyContent: JustifyContent.between,
                gap: 10,
                flexWrap: FlexWrap.wrap,
              ),
            ),
            children: [
              FlintElement(
                'div',
                props: mergeComponentProps(
                  const {},
                  dartStyle: const DartStyle(
                    display: Display.flex,
                    alignItems: AlignItems.center,
                    gap: 8,
                  ),
                ),
                children: [
                  FlintElement(
                    'strong',
                    props: mergeComponentProps(
                      const {},
                      dartStyle: DartStyle(
                        color: ThemeToken.color(
                          'text',
                          fallback: '#0f172a',
                        ).toCss(),
                        fontSize: 13,
                      ),
                    ),
                    children: [FlintText(title)],
                  ),
                  FlintElement(
                    'span',
                    props: {
                      'id': '$_instanceId-status',
                      'data-state': _connectionState.name,
                      'style': {
                        'font-size': '12px',
                        'color': _stateColor(_connectionState),
                      },
                    },
                    children: [FlintText(_stateLabel(_connectionState))],
                  ),
                ],
              ),
              FlintElement(
                'div',
                props: mergeComponentProps(
                  const {},
                  dartStyle: const DartStyle(display: Display.flex, gap: 6),
                ),
                children: [
                  Button(
                    variant: ButtonVariant.outline,
                    size: ComponentSize.sm,
                    onPressed: (_) => reconnect(),
                    child: 'Reconnect',
                  ),
                  Button(
                    variant: ButtonVariant.outline,
                    size: ComponentSize.sm,
                    onPressed: (_) => clear(),
                    child: 'Clear',
                  ),
                  Button(
                    variant: ButtonVariant.outline,
                    size: ComponentSize.sm,
                    onPressed: (_) => unawaited(copySelection()),
                    child: 'Copy',
                  ),
                ],
              ),
            ],
          ),
        FlintElement(
          'div',
          props: mergeComponentProps(
            {
              'id': '$_instanceId-mount',
              'role': 'application',
              'aria-label': '$title interactive terminal',
              'tabIndex': 0,
            },
            dartStyle: DartStyle(
              width: SizeValue.full,
              height: height,
              overflow: Overflow.hidden,
              padding: const EdgeInsets.all(8),
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
              color: ThemeToken.color(
                'inputText',
                fallback: '#101828',
              ).toCss(),
              fontFamily: ThemeToken.font(
                'mono',
                fallback: FontFamily.monospace,
              ).toCss(),
              fontSize: fontSize,
            ),
          ),
        ),
      ],
    );
  }
}
