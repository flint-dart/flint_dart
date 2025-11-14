import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

class PostModel extends Model<PostModel> {
  String? title;
  String? subTitle;
  @override
  DateTime? createdAt;
  @override
  DateTime? updatedAt;
  @override
  PostModel fromMap(Map<dynamic, dynamic> map) => PostModel()
    ..title = map['title']?.toString()
    ..subTitle = map['subTitle']?.toString()
    ..createdAt = map["created_at"] is String
        ? DateTime.parse(map["created_at"])
        : map["created_at"]
    ..updatedAt = map["updated_at"] is String
        ? DateTime.parse(map["updated_at"])
        : map["updated_at"];

  @override
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subTitle': subTitle,
      "created_at": createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String()
    };
  }

  @override
  Table get table => Table(
        name: 'post_models',
        columns: [
          Column(
            name: 'title',
            type: ColumnType.string,
          ),
          Column(
            name: 'subTitle',
            type: ColumnType.string,
            isNullable: true,
          ),
        ],
      );
}
