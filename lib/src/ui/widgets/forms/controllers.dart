import 'validation.dart';

/// Listener signature used by form and text editing controllers.
typedef FlintVoidCallback = void Function();

/// Mutable text value with listener notifications for controlled inputs.
class TextEditingController {
  /// Creates a text editing controller with optional initial [text].
  TextEditingController({String text = ''}) : _text = text;

  String _text;
  final List<FlintVoidCallback> _listeners = [];

  /// Current text value.
  String get text => _text;

  set text(String value) {
    if (_text == value) return;
    _text = value;
    _notifyListeners();
  }

  /// Whether [text] is empty.
  bool get isEmpty => _text.isEmpty;

  /// Whether [text] has at least one character.
  bool get isNotEmpty => _text.isNotEmpty;

  /// Clears the current text value.
  void clear() {
    text = '';
  }

  /// Registers a listener called whenever [text] changes.
  void addListener(FlintVoidCallback listener) {
    _listeners.add(listener);
  }

  /// Removes a previously registered listener.
  void removeListener(FlintVoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in List<FlintVoidCallback>.of(_listeners)) {
      listener();
    }
  }
}

/// Creates a [FormController] initialized with [initialValues].
FormController useForm(Map<String, Object?> initialValues) {
  return FormController(initialValues);
}

/// Stateful helper for form data, validation errors, and submit lifecycle.
class FormController {
  /// Creates a form controller from initial field values.
  FormController(Map<String, Object?> initialValues)
    : _defaults = Map<String, Object?>.from(initialValues),
      _data = Map<String, Object?>.from(initialValues);

  final Map<String, Object?> _defaults;
  final Map<String, Object?> _data;
  final Map<String, TextEditingController> _controllers = {};
  final List<FlintVoidCallback> _listeners = [];

  /// Current validation errors keyed by field name.
  FormErrors errors = const FormErrors();

  /// Whether a submit action is currently running.
  bool processing = false;

  /// Whether the most recent submit completed successfully.
  bool wasSuccessful = false;

  /// Whether the form has recently completed a successful submit.
  bool recentlySuccessful = false;

  /// Immutable snapshot of current form data.
  Map<String, Object?> get data => Map<String, Object?>.unmodifiable(_data);

  /// Gets the raw value for [key].
  Object? operator [](String key) => _data[key];

  /// Gets the field value for [key] as a string.
  String string(String key) => _data[key]?.toString() ?? '';

  /// Returns a text controller synchronized with the field named [key].
  TextEditingController controller(String key) {
    return _controllers.putIfAbsent(key, () {
      final controller = TextEditingController(text: string(key));
      controller.addListener(() {
        _data[key] = controller.text;
        _notifyListeners();
      });
      return controller;
    });
  }

  /// Updates one field value and notifies listeners.
  void setField(String key, Object? value) {
    _data[key] = value;
    final controller = _controllers[key];
    if (controller != null && controller.text != (value?.toString() ?? '')) {
      controller.text = value?.toString() ?? '';
      return;
    }
    _notifyListeners();
  }

  /// Returns the first validation message for [key], if any.
  String? error(String key) => errors.field(key);

  /// Adds a validation error for one field.
  void setError(String key, Object message) {
    errors = errors.merge(FormErrors.from({key: message}));
    _notifyListeners();
  }

  /// Replaces validation errors from a supported error payload.
  void setErrors(Object? messages) {
    errors = FormErrors.from(messages);
    _notifyListeners();
  }

  /// Clears all validation errors, or only errors for [keys].
  void clearErrors([List<String> keys = const []]) {
    if (keys.isEmpty) {
      errors = const FormErrors();
    } else {
      errors = errors.without(keys);
    }
    _notifyListeners();
  }

  /// Resets all fields, or only [keys], to their initial values.
  void reset([List<String> keys = const []]) {
    final resetKeys = keys.isEmpty ? _defaults.keys : keys;
    for (final key in resetKeys) {
      setField(key, _defaults[key]);
    }
    clearErrors(keys.toList());
  }

  /// Runs [action] with current data and updates submit state.
  Future<T?> submit<T>(
    Future<T> Function(Map<String, Object?> data) action, {
    void Function(T result)? onSuccess,
    void Function(Object error)? onError,
    void Function(FormErrors errors)? onValidationError,
    bool resetOnSuccess = false,
  }) async {
    processing = true;
    wasSuccessful = false;
    recentlySuccessful = false;
    clearErrors();

    try {
      final result = await action(data);
      wasSuccessful = true;
      recentlySuccessful = true;
      if (resetOnSuccess) reset();
      onSuccess?.call(result);
      return result;
    } catch (error) {
      final validationErrors = FormErrors.from(error);
      if (validationErrors.isNotEmpty) {
        errors = validationErrors;
        onValidationError?.call(validationErrors);
      }
      onError?.call(error);
      return null;
    } finally {
      processing = false;
      _notifyListeners();
    }
  }

  /// Registers a listener called whenever form state changes.
  void addListener(FlintVoidCallback listener) {
    _listeners.add(listener);
  }

  /// Removes a previously registered form state listener.
  void removeListener(FlintVoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in List<FlintVoidCallback>.of(_listeners)) {
      listener();
    }
  }
}
