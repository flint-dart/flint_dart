import '../component.dart';

/// Called when a [StateSignal] changes.
typedef StateSignalCallback<T> = void Function(T value);

/// Cancels a [StateSignal.listen] subscription.
typedef StateSignalSubscription = void Function();

/// Builds UI from a [StateSignal] value.
typedef StateSignalBuilder<T> = View Function(T value);

/// A tiny reactive value for Flint UI components.
///
/// Use [StateSignal] when a value can change after the first render, for
/// example data from a WebSocket, a timer, or a client-side form.
///
/// ```dart
/// final count = StateSignal<int>(0);
///
/// count.value = count.value + 1;
/// ```
///
/// To rebuild UI automatically, wrap the changing part of the page with
/// [StateSignalListener].
class StateSignal<T> {
  /// Creates a signal with an initial [value].
  StateSignal(this._value);

  T _value;
  final Set<StateSignalCallback<T>> _listeners = {};

  /// The current value.
  T get value => _value;

  /// Replaces the current value and notifies every listener.
  set value(T next) => set(next);

  /// Replaces the current value and notifies every listener.
  void set(T next) {
    _value = next;
    notifyListeners();
  }

  /// Replaces the value by calculating a new value from the current value.
  ///
  /// This is useful for immutable list/map updates:
  ///
  /// ```dart
  /// answers.update((items) => [...items, newAnswer]);
  /// ```
  T update(T Function(T value) updater) {
    final next = updater(_value);
    set(next);
    return next;
  }

  /// Runs [listener] whenever the signal changes.
  ///
  /// Returns a function that stops listening.
  StateSignalSubscription listen(
    StateSignalCallback<T> listener, {
    bool fireImmediately = false,
  }) {
    _listeners.add(listener);
    if (fireImmediately) {
      listener(_value);
    }
    return () => _listeners.remove(listener);
  }

  /// Notifies listeners without replacing the value.
  ///
  /// Use this only when the value itself was mutated:
  ///
  /// ```dart
  /// answers.value.add(newAnswer);
  /// answers.notifyListeners();
  /// ```
  void notifyListeners() {
    for (final listener in List<StateSignalCallback<T>>.from(_listeners)) {
      listener(_value);
    }
  }

  /// Short alias for [notifyListeners].
  void notify() => notifyListeners();

  /// Removes every listener.
  ///
  /// Call this only when the signal is owned by a component that is being
  /// removed. Shared/global signals usually should not be disposed by a page.
  void dispose() {
    _listeners.clear();
  }
}

/// Rebuilds its child whenever a [StateSignal] changes.
///
/// This component removes the need to manually call:
///
/// ```dart
/// signal.listen((_) => setState(() {}));
/// ```
///
/// Instead, put the signal-dependent UI inside this listener:
///
/// ```dart
/// StateSignalListener(answers, (items) {
///   return Column(
///     children: [
///       for (final item in items) AnswerCard(item),
///     ],
///   );
/// });
/// ```
class StateSignalListener<T> extends StatefulComponent {
  /// Creates a component that rebuilds when [signal] changes.
  StateSignalListener(this.signal, this.builder);

  StateSignal<T> signal;
  StateSignalBuilder<T> builder;

  StateSignal<T>? _boundSignal;
  StateSignalSubscription? _unsubscribe;

  @override
  View build() => builder(signal.value);

  @override
  void didMount() {
    _bindSignal();
  }

  @override
  void didUpdate() {
    _bindSignal();
  }

  @override
  void updateFrom(covariant StateSignalListener<T> next) {
    signal = next.signal;
    builder = next.builder;
  }

  @override
  void willUnmount() {
    _unsubscribe?.call();
    _unsubscribe = null;
    _boundSignal = null;
  }

  void _bindSignal() {
    if (identical(_boundSignal, signal)) return;
    _unsubscribe?.call();
    _boundSignal = signal;
    _unsubscribe = signal.listen((_) {
      setState(() {});
    });
  }
}
