# Flint Web UI Example

This example shows Flint Web UI as a small React-style Dart component app.

Source lives in `flint_ui/` and compiled browser files go into `web/`.

Recommended layout:

```text
flint_ui/
  main.dart
  component_registry.dart
  pages/
    welcome_page.dart
    guide_page.dart
    counter_app.dart
web/
  index.html
  style.css
  main.dart.js
```

Optional Tailwind setup without `npm`:

1. Install the standalone Tailwind binary somewhere on your machine, for example:
   `C:\tools\tailwindcss\tailwindcss.exe`
2. Either add that folder to `PATH`, or set:
   `FLINT_TAILWIND_BIN=C:\tools\tailwindcss\tailwindcss.exe`
3. Author Tailwind input in:
   `flint_ui/tailwind.css`
4. Flint will compile it to:
   `web/style.css`

The example includes a starter [tailwind.css](D:/eulogia/flint/flint_dart/example/flint_ui/flint_ui/tailwind.css).

Build and serve with Flint:

```bash
flint web
```

Or build only:

```bash
flint web --build-only
```

This compiles `flint_ui/main.dart` to `web/main.dart.js`.
If `flint_ui/tailwind.css` exists, Flint also compiles it to `web/style.css`.

`flint run` also compiles the Flint UI bundle before starting the backend server.
Use `flint run --no-web-build` to skip that step.

Core API:

```dart
import 'package:flint_ui/flint_ui.dart';

void main() {
  createFlintApp('#app', pages: {
    'Counter': (props) => CounterApp(props),
  });
}

class CounterApp extends FlintComponent {
  final Map<String, dynamic> props;
  int count = 0;

  CounterApp(this.props);

  @override
  FlintNode build() {
    return Button(
      onPressed: (_) => setState(() => count++),
      child: Text('Count: $count'),
    );
  }
}
```


