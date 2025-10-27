import 'package:flint_dart/flint_dart.dart';
import 'package:sample/src/models/post_model.dart';

class PostController {
  Future<Response> index(Request req, Response res) async {
    return res.json({'message': 'PostController index'});
  }

  Future<Response> show(Request req, Response res) async {
    final id = req.params['id'];
    return res.json({'message': 'Showing PostController with id: $id'});
  }

  Future<Response> store(Request req, Response res) async {
    final body = await req.validate({
      'title': 'required|string|min:3',
      'subTitle': 'required|string|min:3'
    });
    PostModel().create(body);
    return res
        .json({'message': 'PostController created successfully', 'data': body});
  }

  Future<Response> update(Request req, Response res) async {
    final id = req.params['id'];
    final body = await req.validate({
      'title': 'required|string|min:3',
      'subTitle': 'required|string|min:3'
    });
    // PostModel().create(body);
    await PostModel().update(id, body);
    return res.json({'message': 'PostController  updated', 'data': body});
  }

  Future<Response> destroy(Request req, Response res) async {
    final id = req.params['id'];
    return res.json({'message': 'PostController  deleted $id'});
  }
}
