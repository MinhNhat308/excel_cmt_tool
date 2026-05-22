import 'dart:convert';
import 'dart:io';
import '../models/project_model.dart';

class FgService {
  static const String _masterKey = 'FUGE_MASTER_KEY_2026';

  // Mã hóa chuỗi JSON dùng XOR với masterKey và chuyển sang Base64
  String encrypt(String jsonStr) {
    final bytes = utf8.encode(jsonStr);
    final keyBytes = utf8.encode(_masterKey);
    final encryptedBytes = List<int>.generate(bytes.length, (i) {
      return bytes[i] ^ keyBytes[i % keyBytes.length];
    });
    return base64Encode(encryptedBytes);
  }

  // Giải mã từ Base64 dùng XOR với masterKey
  String decrypt(String base64Str) {
    final bytes = base64Decode(base64Str.trim());
    final keyBytes = utf8.encode(_masterKey);
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
  }) async {
    final Map<String, dynamic> data = {
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
    final encryptedStr = encrypt(jsonStr);
    await File(filePath).writeAsString(encryptedStr, encoding: utf8, flush: true);
  }

  // Đọc danh sách dự án và thông tin chung từ file .fg
  Map<String, dynamic> loadFromFile(String filePath) {
    final content = File(filePath).readAsStringSync(encoding: utf8);
    final jsonStr = decrypt(content);
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }
}
