import '../../component.dart';
import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import '../actions/button.dart';
import '../shared/theme.dart';

/// Connection lifecycle states reported by [Terminal].
enum TerminalConnectionState {
  /// No connection has been requested yet.
  idle,

  /// A WebSocket connection is being established.
  connecting,

  /// Input and output can flow through the WebSocket.
  connected,

  /// The terminal is waiting to retry a dropped connection.
  reconnecting,

  /// The most recent connection attempt failed.
  error,

  /// The connection was closed or explicitly disconnected.
  closed,
}

/// Light and dark colors used by the xterm.js renderer.
class TerminalTheme {
  /// Creates a terminal color palette.
  const TerminalTheme({
    this.lightBackground = '#ffffff',
    this.lightForeground = '#0f172a',
    this.lightCursor = '#0284c7',
    this.lightSelection = 'rgba(2, 132, 199, 0.22)',
    this.darkBackground = '#020617',
    this.darkForeground = '#f8fafc',
    this.darkCursor = '#38bdf8',
    this.darkSelection = 'rgba(56, 189, 248, 0.28)',
  });

  /// Terminal background in light mode.
  final String lightBackground;

  /// Terminal foreground in light mode.
  final String lightForeground;

  /// Terminal cursor in light mode.
  final String lightCursor;

  /// Terminal selection in light mode.
  final String lightSelection;

  /// Terminal background in dark mode.
  final String darkBackground;

  /// Terminal foreground in dark mode.
  final String darkForeground;

  /// Terminal cursor in dark mode.
  final String darkCursor;

  /// Terminal selection in dark mode.
  final String darkSelection;
}

/// Imperative controls for a mounted [Terminal].
class TerminalController {
  Object? _owner;
  void Function()? _connect;
  void Function()? _reconnect;
  void Function()? _disconnect;
  void Function()? _clear;
  void Function()? _focus;
  void Function(String data)? _write;
  bool Function(String data)? _send;
  Future<bool> Function()? _copySelection;
  TerminalConnectionState _connectionState = TerminalConnectionState.idle;

  /// Whether this controller is currently attached to a browser terminal.
  bool get isAttached => _owner != null;

  /// The last connection state reported by the terminal.
  TerminalConnectionState get connectionState => _connectionState;

  /// Connects the terminal WebSocket.
  void connect() => _connect?.call();

  /// Closes the current socket and establishes a fresh connection.
  void reconnect() => _reconnect?.call();

  /// Closes the current terminal WebSocket.
  void disconnect() => _disconnect?.call();

  /// Clears the visible terminal buffer.
  void clear() => _clear?.call();

  /// Moves keyboard focus to the terminal.
  void focus() => _focus?.call();

  /// Writes local text to the terminal without sending it to the server.
  void write(String data) => _write?.call(data);

  /// Sends input to the connected terminal server.
  bool send(String data) => _send?.call(data) ?? false;

  /// Copies the current terminal selection to the system clipboard.
  Future<bool> copySelection() =>
      _copySelection?.call() ?? Future<bool>.value(false);

  /// Binds browser behavior to this controller.
  ///
  /// This is called by [Terminal] during its mount lifecycle. Application code
  /// normally uses the command methods above instead of calling [attach].
  void attach({
    required Object owner,
    required void Function() connect,
    required void Function() reconnect,
    required void Function() disconnect,
    required void Function() clear,
    required void Function() focus,
    required void Function(String data) write,
    required bool Function(String data) send,
    required Future<bool> Function() copySelection,
  }) {
    _owner = owner;
    _connect = connect;
    _reconnect = reconnect;
    _disconnect = disconnect;
    _clear = clear;
    _focus = focus;
    _write = write;
    _send = send;
    _copySelection = copySelection;
  }

  /// Removes browser behavior when the owning terminal unmounts.
  void detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _connect = null;
    _reconnect = null;
    _disconnect = null;
    _clear = null;
    _focus = null;
    _write = null;
    _send = null;
    _copySelection = null;
    _connectionState = TerminalConnectionState.closed;
  }

  /// Mirrors the state of the attached terminal.
  void updateConnectionState(Object owner, TerminalConnectionState state) {
    if (!identical(_owner, owner)) return;
    _connectionState = state;
  }
}

/// Server-safe representation of Flint's interactive browser terminal.
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
    this.theme = const TerminalTheme(),
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
  final String websocketUrl;

  /// Optional imperative terminal controller.
  final TerminalController? controller;

  /// Toolbar title.
  final String title;

  /// Terminal viewport height.
  final Object height;

  /// Whether reconnect, clear, and copy actions are shown.
  final bool showToolbar;

  /// Whether to connect after the browser component mounts.
  final bool autoConnect;

  /// Whether unexpected socket closures should be retried.
  final bool autoReconnect;

  /// Delay before reconnecting a dropped socket.
  final Duration reconnectDelay;

  /// Whether terminal size changes are sent as JSON resize envelopes.
  final bool sendResizeMessages;

  /// Terminal font size in pixels.
  final int fontSize;

  /// Terminal monospace font stack.
  final String fontFamily;

  /// Maximum number of retained terminal lines.
  final int scrollback;

  /// Light and dark xterm.js colors.
  final TerminalTheme theme;

  /// Text written before the first connection attempt.
  final String connectingMessage;

  /// xterm.js browser script URL.
  final String scriptUrl;

  /// xterm.js stylesheet URL.
  final String stylesheetUrl;

  /// Optional wrapper class name.
  final String? className;

  /// Additional wrapper HTML properties.
  final Map<String, Object?> props;

  /// Additional wrapper inline styles.
  final Map<String, Object?> style;

  /// Additional typed wrapper styles.
  final DartStyle? dartStyle;

  /// Called whenever the WebSocket connection state changes.
  final void Function(TerminalConnectionState state)? onConnectionStateChanged;

  /// Called after keyboard input is sent.
  final void Function(String data)? onInput;

  /// Called when terminal output is received.
  final void Function(String data)? onOutput;

  /// Called when the terminal calculates a new character grid size.
  final void Function(int columns, int rows)? onResize;

  /// Called when asset loading or the WebSocket reports an error.
  final void Function(Object error)? onError;

  static int _nextId = 0;
  late final String _instanceId = 'flint-terminal-${_nextId++}';

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
                      'data-state': TerminalConnectionState.idle.name,
                      'style': {
                        'font-size': '12px',
                        'color': ThemeToken.color(
                          'muted',
                          fallback: '#667085',
                        ).toCss(),
                      },
                    },
                    children: const [FlintText('Ready')],
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
                    child: 'Reconnect',
                  ),
                  Button(
                    variant: ButtonVariant.outline,
                    size: ComponentSize.sm,
                    child: 'Clear',
                  ),
                  Button(
                    variant: ButtonVariant.outline,
                    size: ComponentSize.sm,
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
          children: const [
            FlintText('Interactive terminal loads in the browser.'),
          ],
        ),
      ],
    );
  }
}
