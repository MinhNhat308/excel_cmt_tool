import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';

class FgFugeCryptoService {
  static const _defaultKey = 'l10ca968o8e4133tyne2ea2315g19377';

  static final _key = Key.fromUtf8(_defaultKey);
  static final _iv = IV(Uint8List(16));
  static final _encrypter = Encrypter(
    AES(_key, mode: AESMode.cbc, padding: 'PKCS7'),
  );

  String decryptFgFileText(String base64Cipher) {
    final cipher = Encrypted.fromBase64(base64Cipher.trim());
    return _encrypter.decrypt(cipher, iv: _iv);
  }

  String encryptToFgFileText(String plainJson) {
    final encrypted = _encrypter.encrypt(plainJson, iv: _iv);
    return encrypted.base64;
  }

  String decryptFgBytes(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true).trim();
    if (text.startsWith('{') || text.startsWith('[')) {
      return text;
    }
    return decryptFgFileText(text);
  }

  List<int> encryptFgBytes(String plainJson) {
    return utf8.encode(encryptToFgFileText(plainJson));
  }
}
