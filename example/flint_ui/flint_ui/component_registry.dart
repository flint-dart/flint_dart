import 'package:flint_ui/flint_ui.dart';

import 'pages/counter_app.dart';
import 'pages/guide_page.dart';
import 'pages/login_page.dart';
import 'pages/welcome_page.dart';

final componentRegistry = FlintComponentRegistry({
  'Welcome': (props) => WelcomePage(props),
  'Guide': (props) => GuidePage(props),
  'Login': (props) => LoginPage(props),
  'Counter': (props) => CounterApp(props),
});
