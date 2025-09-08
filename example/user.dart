import 'package:flint_dart/flint_dart.dart';

void userData(Flint app) {
  app.get("/", (req, res) => res.json({"user": "i love"}));

  app.get("/love", (req, res) async {
    return res.json({"user": "i love you"});
  });
}
