import 'package:flint_dart/auth.dart';
import 'package:flint_dart/flint_dart.dart';
import 'package:sample/src/models/user_model.dart';

class AuthController {
  Future<Response> register(Request req, Response res) async {
    try {
      final body = await req.json();
      await Validator.validate(body, {
        "email": "required|string|email|min:3",
        "name": "required|string|min:5",
        "password": "required|string|min:8"
      });
      String hashPassword = Hashing().hash(body["password"]);
      body["password"] = hashPassword;
      final User? user = await User().create(body);

      return res.json({"status": "success", "data": user?.toMap()});
    } on ValidationException catch (e) {
      return res.status(422).json({"status": "errors", "errors": e.errors});
    } catch (e) {
      return res.status(422).json(
        {"status": "error", "message": e.toString()},
      );
    }
  }

  Future<Response> login(Request req, Response res) async {
    try {
      var body = await req.validate(
          {"email": "required|string", "password": "required|string"});

      final token = await Auth.login(body['email'], body["password"]);

      return res.json({
        "status": "successfull",
        "data": {"token": token}
      });
    } on ValidationException catch (e) {
      return res.status(422).json({"status": "errors", "errors": e});
    } catch (e) {
      return res.status(422).json({"status": "errors", "errors": e.toString()});
    }
  }

  Future<Response> loginWithGoogle(Request req, Response res) async {
    try {
      final body = await req.json();

      // Check if idToken or code is present and validate
      await Validator.validate(body,
          {"idToken": "string", "code": "string", "callbackPath": "string"});

      // Pass either idToken or code to the Auth class
      final Map<String, dynamic> authResult = await Auth.loginWithGoogle(
        idToken: body['idToken'],
        code: body['code'],
        callbackPath: body['callbackPath'],
      );

      return res.json({
        "status": "success",
        "data": authResult,
      });
    } on ArgumentError catch (e) {
      return res.status(400).json({"status": "error", "message": e.message});
    } on ValidationException catch (e) {
      return res.status(400).json({"status": "error", "message": e.errors});
    } catch (e) {
      return res.status(401).json({"status": "error", "message": e.toString()});
    }
  }

  Future<Response> update(Request req, Response res) async {
    return res.send('Updating item ${req.params['id']}');
  }

  Future<Response> delete(Request req, Response res) async {
    return res.send('Deleting item ${req.params['id']}');
  }
}
