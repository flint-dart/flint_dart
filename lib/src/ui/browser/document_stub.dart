class FlintDocument {
  const FlintDocument();

  Object? get raw => null;
  Object? get documentElement => null;
  Object? get head => null;
  Object? get body => null;
  String get title => '';
  set title(String value) {}
  Object? querySelector(String selector) => null;
  Object? getElementById(String id) => null;
  int get scrollWidth => 0;
  int get scrollHeight => 0;
  int get clientWidth => 0;
  int get clientHeight => 0;
  bool get hasHorizontalOverflow => false;
}

const flintDocument = FlintDocument();
