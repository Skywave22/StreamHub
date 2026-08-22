import 'dart:convert';

import 'package:crypto/crypto.dart';

/// SHA-256 helpers used for plugin verification and release checksums.
abstract final class Checksum {
  static String sha256Hex(String input) => sha256.convert(utf8.encode(input)).toString();

  static String sha256HexBytes(List<int> bytes) => sha256.convert(bytes).toString();
}
