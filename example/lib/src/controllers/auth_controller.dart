import 'package:flint_dart/auth.dart';
import 'package:flint_dart/flint_dart.dart';

class AuthController {
  Future<Response> register(Request req, Response res) async {
    var data = await req.validate({
      "name": "string|required",
      "email": "string|required",
      "password": "string|required|confirmed",
    });

    var user = await Auth.register(
      email: data["email"],
      password: data['password'],
      name: data["name"],
    );
    return res.respond({"msg": "user created succesfuly", "data": user});
  }

  Future<Response> login(Request req, Response res) async {
    final data = await req.validate({
      "email": "required|string",
      "password": "required:string",
    });

    final user = await Auth.login(data["email"], "password");

    return res.respond({"msg": "login successfuly", "data": user});
  }
}
