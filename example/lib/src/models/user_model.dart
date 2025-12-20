import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';
import 'package:sample/src/models/post_model.dart';

class User extends Model<User> {
  User() : super(() => User());
  @override
  int? id;
  String? name;
  String? email;
  String? password;
  String? profilePicUrl;
  @override
  DateTime? createdAt;
  @override
  DateTime? updatedAt;

  @override
  User fromMap(Map<dynamic, dynamic> map) => User()
    ..id = map['id']
    ..name = map['name']
    ..email = map['email']
    ..password = map["password"]
    ..createdAt = map["created_at"]
    ..updatedAt = map["updated_at"];

  @override
  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "name": name,
      "email": email,
      "profilePicUrl": profilePicUrl,
      "created_at": createdAt,
      "updated_at": updatedAt
    };
  }

  @override
  Table get table => Table(
        name: 'users',
        columns: [
          Column(name: 'name', type: ColumnType.string, length: 255),
          Column(name: 'email', type: ColumnType.string, length: 255),
          Column(
              name: 'profilePicUrl',
              type: ColumnType.string,
              length: 255,
              isNullable: true),
          Column(
            name: 'password',
            type: ColumnType.string,
          ),
        ],
      );

  Future<List<PostModel>> post() => hasMany(() => PostModel());
}
