import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
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
    final content = File(filePath).readAsStringSync(encoding: utf8).trim();

    // 1. Thử chuẩn cũ (XOR)
    try {
      final jsonStr = decrypt(content, password);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (decoded['signature'] == 'FUGE_DECRYPT_OK') {
        return decoded;
      }
    } catch (_) {
      // Ignored, try AES fallback
    }

    // 2. Thử chuẩn FuGrade gốc (AES hoặc plain text)
    String? plainText;
    if (content.startsWith('{') || content.startsWith('[')) {
      plainText = content;
    } else {
      try {
        final key = enc.Key.fromUtf8('l10ca968o8e4133tyne2ea2315g19377');
        final iv = enc.IV(Uint8List(16));
        final encrypter = enc.Encrypter(
          enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'),
        );
        final cipher = enc.Encrypted.fromBase64(content);
        plainText = encrypter.decrypt(cipher, iv: iv);
      } catch (e) {
        throw FormatException('Khóa giải mã không chính xác hoặc tệp hỏng: $e');
      }
    }

    if (plainText == null) {
      throw const FormatException('Không thể giải mã tệp.');
    }

    final decoded = jsonDecode(plainText) as Map<String, dynamic>;

    // Kiểm tra mật khẩu (chuẩn gốc của trường)
    if (decoded.containsKey('Password')) {
      final expectedHash = decoded['Password']?.toString() ?? '';
      final inputPassword = password.isEmpty ? '1' : password;
      final inputHash = md5.convert(utf8.encode(inputPassword)).toString();

      final matchesMd5 = inputHash == expectedHash;
      final matchesPlainText = inputPassword == expectedHash;

      if (expectedHash.isNotEmpty && !matchesMd5 && !matchesPlainText) {
        throw const FormatException('Khóa giải mã không chính xác.');
      }
    }

    // Nếu là chuẩn FuGrade gốc, xử lý node SubjectClassGrades
    if (decoded.containsKey('SubjectClassGrades')) {
      final classes = decoded['SubjectClassGrades'] as List<dynamic>? ?? [];
      final projects = <ProjectModel>[];
      final subjectPrefixes = const ['SEP'];

      String firstSubjectCode = '';

      for (final entry in classes) {
        final sc = Map<String, dynamic>.from(entry as Map);
        final subject = sc['Subject']?.toString() ?? '';
        if (!subjectPrefixes.any((p) => subject.toUpperCase().startsWith(p.toUpperCase()))) {
          continue;
        }
        if (firstSubjectCode.isEmpty) {
          firstSubjectCode = subject;
        }

        final groupCode = sc['Class']?.toString() ?? '';
        final studentsList = sc['Students'] as List<dynamic>? ?? [];
        final students = <StudentModel>[];

        for (final st in studentsList) {
          final sm = Map<String, dynamic>.from(st as Map);
          final roll = sm['Roll']?.toString() ?? '';
          final name = sm['Name']?.toString() ?? '';
          if (roll.isEmpty && name.isEmpty) continue;
          students.add(StudentModel(roll: roll, name: name));
        }

        if (students.isNotEmpty) {
          projects.add(ProjectModel(
            topicCode: '',
            titleVn: '',
            titleEn: '',
            groupCode: groupCode,
            students: students,
          ));
        }
      }

      return {
        'signature': 'FUGE_DECRYPT_OK',
        'metadata': {
          'teacher': decoded['Login']?.toString() ?? '',
          'semester': decoded['Semester']?.toString() ?? '',
          'subject_code': firstSubjectCode,
          'class_name': '',
          'created_at': DateTime.now().toIso8601String(),
        },
        'projects': projects.map((p) => p.toJson()).toList(),
      };
    }

    throw const FormatException('Định dạng tệp .fg không được hỗ trợ.');
  }
}
