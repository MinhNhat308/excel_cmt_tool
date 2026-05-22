import 'dart:convert';
import 'dart:io';
import '../models/project_model.dart';

class FgService {
  // Mã hóa chuỗi JSON dùng XOR với password và chuyển sang Base64
  String encrypt(String jsonStr, String password) {
    final cleanPassword = password.isEmpty ? '1' : password;
    final bytes = utf8.encode(jsonStr);
    final keyBytes = utf8.encode(cleanPassword);
    final encryptedBytes = List<int>.generate(bytes.length, (i) {
      return bytes[i] ^ keyBytes[i % keyBytes.length];
    });
    return base64Encode(encryptedBytes);
  }

  // Giải mã từ Base64 dùng XOR với password
  String decrypt(String base64Str, String password) {
    final cleanPassword = password.isEmpty ? '1' : password;
    final bytes = base64Decode(base64Str.trim());
    final keyBytes = utf8.encode(cleanPassword);
    final decryptedBytes = List<int>.generate(bytes.length, (i) {
      return bytes[i] ^ keyBytes[i % keyBytes.length];
    });
    return utf8.decode(decryptedBytes);
  }

  // Lưu toàn bộ dữ liệu danh sách dự án vào file .fg
  Future<void> saveToFile({
    required String filePath,
    required String teacher,
    required String semester,
    required String subjectCode,
    required String className,
    required List<ProjectModel> projects,
    required String password,
  }) async {
    final Map<String, dynamic> data = {
      'signature': 'FUGE_DECRYPT_OK',
      'version': '1.0',
      'metadata': {
        'teacher': teacher,
        'semester': semester,
        'subject_code': subjectCode,
        'class_name': className,
        'created_at': DateTime.now().toIso8601String(),
      },
      'projects': projects.map((p) => p.toJson()).toList(),
    };

    final jsonStr = jsonEncode(data);
    final encryptedStr = encrypt(jsonStr, password);
    await File(filePath).writeAsString(encryptedStr, encoding: utf8, flush: true);
  }

  // Đọc danh sách dự án và thông tin chung từ file .fg
  Map<String, dynamic> loadFromFile(String filePath, String password) {
    final content = File(filePath).readAsStringSync(encoding: utf8);
    final jsonStr = decrypt(content, password);
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    if (decoded['signature'] != 'FUGE_DECRYPT_OK') {
      throw const FormatException('Khóa giải mã không chính xác.');
    }
    return decoded;
  }
}
