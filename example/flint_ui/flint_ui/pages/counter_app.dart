import 'package:flint_dart/ui.dart';

class CounterApp extends FlintComponent {
  final Map<String, dynamic> props;
  int count = 0;

  CounterApp(this.props) {
    count = props['initialCount'] is int ? props['initialCount'] as int : 0;
  }

  @override
  FlintNode build() {
    return Container(
      props: {
        'className': 'app-shell',
      },
      children: [
        h('h1', children: ['Flint Web UI']),
        h('p', children: [
          props['message'] ??
              'A Flutter-style Dart component rendered in the browser.'
        ]),
        Row(
          props: {'className': 'counter'},
          children: [
            Button(
              props: {
                'className': 'icon-button',
                'aria-label': 'Decrease',
              },
              onPressed: (_) => setState(() => count--),
              child: Text('-'),
            ),
            Container(
              props: {'className': 'count'},
              child: Text(count),
            ),
            Button(
              props: {
                'className': 'icon-button',
                'aria-label': 'Increase',
              },
              onPressed: (_) => setState(() => count++),
              child: Text('+'),
            ),
          ],
        ),
      ],
    );
  }
}
