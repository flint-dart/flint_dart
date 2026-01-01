// File: lib/src/security/hashing.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:bcrypt/bcrypt.dart';

enum HashingAlgorithm { bcrypt, sha256 }

class Hashing {
  final HashingAlgorithm algorithm;

  const Hashing({this.algorithm = HashingAlgorithm.bcrypt});

  String hash(String password) {
    switch (algorithm) {
      case HashingAlgorithm.bcrypt:
        return BCrypt.hashpw(password, BCrypt.gensalt());
      case HashingAlgorithm.sha256:
        return sha256.convert(utf8.encode(password)).toString();
    }
  }

  bool verify(String password, String hash) {
    if (hash == "null" || hash.isEmpty) {
      // Optionally: throw an exception or return false
      return false;
    }
    switch (algorithm) {
      case HashingAlgorithm.bcrypt:
        return BCrypt.checkpw(password, hash);
      case HashingAlgorithm.sha256:
        return sha256.convert(utf8.encode(password)).toString() == hash;
    }
  }
}
