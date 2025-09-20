import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

class PostModel extends Model<PostModel> {
  int? id;
  String? title;
  String? subTitle;

  @override
  Table get table => Table(
        name: 'post_models',
        columns: [
          Column(
              name: 'id',
              type: ColumnType.integer,
              isPrimaryKey: true,
              isAutoIncrement: true),
          Column(name: 'title', type: ColumnType.string),
          Column(name: 'subTitle', type: ColumnType.string),
        ],
      );

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
      };

  @override
  PostModel fromMap(Map<dynamic, dynamic> map) {
    return PostModel()
      ..id = map['id']
      ..title = map['title'];
  }
}
