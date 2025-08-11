import 'package:flint_dart/flint_dart.dart';

import 'user.dart';

void main() {
  final app = Flint(rootPath: "example");

  // app.setPath('example'); // Watch 'example' folder instead of default 'bin'
  app.use(LoggerMiddleware());

  app.get('/', (req, res) async {
    res.send('Hello World');
  });
  app.get('/ibk', (req, res) async {
    res.send('Hello ibk');
  });

  app.get('/hello', (req, res) async {
    res.send('Hello ibk');
  });

  app.get('/ibks', (req, res) async {
    res.send('Hello ibk');
  });
  app.get('/love', (req, res) async {
    res.send('I love my wife');
  });
  app.get('/wife', (req, res) async {
    res.send('I love my wife');
  });

  app.put('/update', (req, res) async {
    res.send('PUT: updated something');
  });

  app.delete('/remove', (req, res) async {
    res.send('DELETE: deleted somethin');
  });

  app.get('/json', (req, res) async {
    res.json({'message': 'Welcome to Flint Dart'});
  });

  app.mount("/user", userData);

  app.listen(30435);
}

class LoggerMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (req, res) async {
      print('[${req.method}] ${req.path}');
      await next(req, res);
    };
  }
}
