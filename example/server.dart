import 'package:flint_dart/flint_dart.dart';

import 'user.dart';

void main() {
  final app = Flint(rootPath: "example");

  // app.setPath('example'); // Watch 'example' folder instead of default 'bin'
  app.use(LoggerMiddleware());

  app.get('/', (req, res) async {
    return res.send('Hello World');
  });
  app.get('/ibk', (req, res) async {
    return res.send('Hello ibk');
  });

  app.get('/hello', (req, res) async {
    return res.send('Hello ibk');
  });

  app.get('/ibks', (req, res) async {
    return res.send('Hello ibk');
  });
  app.get('/love', (req, res) async {
    return res.send('I love my wife');
  });
  app.get('/wife', (req, res) async {
    return res.send('I love my wife');
  });

  app.put('/update', (req, res) async {
    return res.send('PUT: updated something');
  });

  app.delete('/remove', (req, res) async {
    return res.send('DELETE: deleted somethin');
  });

  app.get('/json', (req, res) async {
    return res.json({'message': 'Welcome to Flint Dart'});
  });

  app.mount("/user", userData);

  app.listen(30435);
}
