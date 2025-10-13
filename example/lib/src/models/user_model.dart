import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

class User extends Model<User> {
  @override
  int? id;
  String? name;
  String? email;
  String? password;
  String? profilePicUrl;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
      };

  @override
  User fromMap(Map<dynamic, dynamic> map) => User()
    ..id = map['id']
    ..name = map['name']
    ..email = map['email']
    ..password = map["password"];

  @override
  Table get table => Table(
        name: 'users',
        columns: [
          Column(
              name: 'id',
              type: ColumnType.integer,
              isPrimaryKey: true,
              isAutoIncrement: true,
              isUnique: true),
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
          Column(
              name: 'created_at',
              type: ColumnType.datetime,
              defaultValue: Default.currentDate()),
          Column(
              name: 'updated_at',
              type: ColumnType.datetime,
              defaultValue: Default.currentTimestamp()),
        ],
      );
}
