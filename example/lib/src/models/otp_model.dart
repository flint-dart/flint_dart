import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

class OtpModel extends Model<OtpModel> {
  @override
  int? id;

  // Define your fields here
  String? otp;
  String? email;
  DateTime? expiredAt;

  @override
  Table get table => Table(
        name: 'otp_models',
        columns: [
          Column(
              name: 'id',
              type: ColumnType.integer,
              isPrimaryKey: true,
              isAutoIncrement: true),
          Column(name: 'otp', type: ColumnType.string),
          Column(name: 'email', type: ColumnType.string),
          Column(name: "expired_at", type: ColumnType.datetime)
        ],
      );

  @override
  Map<String, dynamic> toMap() =>
      {'id': id, 'otp': otp, "email": email, "expired_at": expiredAt};

  @override
  OtpModel fromMap(Map<String, dynamic> map) {
    return OtpModel()
      ..id = map['id']
      ..otp = map['otp']
      ..email = map["email"]
      ..expiredAt = map["expired_at"];
  }
}
