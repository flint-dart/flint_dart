import 'package:flint_dart/flint_dart.dart';

void userData(Flint app) {
  app.get("/", (req, res) async {
    res.json({"user": "i love"});
  });

  app.get("/love", (req, res) async {
    res.json({"user": "i love you"});
  });
}
