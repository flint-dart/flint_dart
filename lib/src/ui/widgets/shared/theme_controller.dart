import 'package:universal_web/web.dart' as web;

import '../../state/state_signal.dart';
import '../../storage/browser_storage.dart';
import '../../storage/local_storage.dart';
import '../../style.dart';

/// Default local storage key used for the active Flint theme mode.
const defaultFlintThemeStorageKey = 'flint.theme.mode';

/// Reactive controller for the active Flint theme mode.
///
/// Use [flintTheme] to switch light/dark mode from UI events and listen to
/// the active mode with [StateSignalListener].
class FlintThemeController {
  /// Creates a theme controller with [initialMode].
  FlintThemeController({FlintThemeMode initialMode = FlintThemeMode.light})
    : mode = StateSignal<FlintThemeMode>(initialMode);

  /// Reactive active theme mode.
  final StateSignal<FlintThemeMode> mode;

  BrowserStorage? _storage;
  String? _storageKey;
  web.Element? _target;

  /// Configures the controller for an app root.
  void configure({
    FlintThemeMode? initialMode,
    BrowserStorage? storage,
    String? storageKey,
    Object? target,
  }) {
    _storage = storage ?? localStorage;
    _storageKey = storageKey ?? defaultFlintThemeStorageKey;
    if (target is web.Element) {
      _target = target;
    }

    mode.value =
        _storedMode() ?? _systemPreferredMode() ?? initialMode ?? mode.value;
    _applyMode(mode.value);
  }

  /// Switches to [next].
  void setMode(FlintThemeMode next) {
    mode.value = next;
    final key = _storageKey;
    if (_storage != null && key != null && key.isNotEmpty) {
      _storage!.write(key, next.value);
    }
    _applyMode(next);
  }

  /// Toggles between light and dark mode.
  FlintThemeMode toggle() {
    final next = mode.value == FlintThemeMode.dark
        ? FlintThemeMode.light
        : FlintThemeMode.dark;
    setMode(next);
    return next;
  }

  /// Switches to light mode.
  void useLight() => setMode(FlintThemeMode.light);

  /// Switches to dark mode.
  void useDark() => setMode(FlintThemeMode.dark);

  FlintThemeMode? _storedMode() {
    final key = _storageKey;
    if (_storage == null || key == null || key.isEmpty) return null;
    return _themeModeFromValue(_storage!.read(key));
  }

  FlintThemeMode? _systemPreferredMode() {
    try {
      return web.window.matchMedia('(prefers-color-scheme: dark)').matches
          ? FlintThemeMode.dark
          : FlintThemeMode.light;
    } catch (_) {
      return null;
    }
  }

  void _applyMode(FlintThemeMode next) {
    web.document.documentElement?.setAttribute('data-theme', next.value);
    final target = _target;
    target?.setAttribute('data-theme', next.value);
  }
}

/// Global theme controller used by Flint UI apps.
final flintTheme = FlintThemeController();

FlintThemeMode? _themeModeFromValue(String? value) {
  return switch (value) {
    'light' => FlintThemeMode.light,
    'dark' => FlintThemeMode.dark,
    _ => null,
  };
}
