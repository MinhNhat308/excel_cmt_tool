import 'dart:convert';

import 'package:crypto/crypto.dart';

class FugradePassword {
  static final _md5Hex = RegExp(r'^[a-fA-F0-9]{32}$');

  static bool looksLikeMd5(String value) => _md5Hex.hasMatch(value.trim());

  static String md5Hex(String plain) {
    return md5.convert(utf8.encode(plain)).toString();
  }

  static String forCmtExport(String input) {
    final t = input.trim();
    if (t.isEmpty) return md5Hex('1');
    if (looksLikeMd5(t)) return t.toLowerCase();
    return md5Hex(t);
  }
}
