import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/thesis_comment.dart';

class CmtExportService {
  static const _exeName = 'FuGrade.exe';

  String? locateExporter() {
    final candidates = <String>[];

    final exe = Platform.resolvedExecutable;
    final exeDir = p.dirname(exe);
    candidates.add(p.join(exeDir, _exeName));

    final cwd = Directory.current.path;
    candidates.add(p.join(cwd, _exeName));
    candidates.add(p.join(cwd, 'tools', 'cmt_exporter', 'bin', 'Release', 'net48', _exeName));

    final script = Platform.script.toFilePath();
    if (script.isNotEmpty) {
      var dir = p.dirname(script);
      for (var i = 0; i < 6; i++) {
        candidates.add(
          p.join(dir, 'tools', 'cmt_exporter', 'bin', 'Release', 'net48', _exeName),
        );
        final parent = p.dirname(dir);
        if (parent == dir) break;
        dir = parent;
      }
    }

    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  Future<void> exportToFile({
    required ThesisComment thesis,
    required String outputPath,
  }) async {
    final exporter = locateExporter();
    if (exporter == null) {
      throw StateError(
        'Không tìm thấy $_exeName.\n'
        'Chạy: dotnet build tools/cmt_exporter/FuGrade.csproj -c Release\n'
        'Rồi copy FuGrade.exe vào cùng thư mục với excel_cmt_tool.exe.',
      );
    }

    final tempDir = await Directory.systemTemp.createTemp('excel_cmt_');
    final jsonPath = p.join(tempDir.path, 'export.json');
    final outPath = p.join(tempDir.path, 'out.cmt');

    try {
      final exportData = thesis.toExportJson();
      final rawPassword = exportData['password'] as String? ?? '';
      final cleanPassword = rawPassword.isEmpty ? '1' : rawPassword;
      final isAlreadyMd5 = cleanPassword.length == 32 && RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(cleanPassword);
      final finalHash = isAlreadyMd5 ? cleanPassword : md5.convert(utf8.encode(cleanPassword)).toString();
      exportData['password'] = finalHash;

      await File(jsonPath).writeAsString(
        jsonEncode(exportData),
        encoding: utf8,
      );

      final result = await Process.run(
        exporter,
        [jsonPath, outPath],
        runInShell: false,
      );

      if (result.exitCode != 0) {
        final err = '${result.stderr}'.trim();
        throw StateError(
          err.isEmpty ? 'FuGrade.exe thoát với mã ${result.exitCode}' : err,
        );
      }

      final bytes = await File(outPath).readAsBytes();
      await File(outputPath).writeAsBytes(bytes, flush: true);
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<ThesisComment> importFromFile({
    required String inputPath,
    required String password,
  }) async {
    final exporter = locateExporter();
    if (exporter == null) {
      throw StateError(
        'Không tìm thấy $_exeName.\n'
        'Chạy: dotnet build tools/cmt_exporter/FuGrade.csproj -c Release\n'
        'Rồi copy FuGrade.exe vào cùng thư mục với excel_cmt_tool.exe.',
      );
    }

    final tempDir = await Directory.systemTemp.createTemp('excel_cmt_import_');
    final jsonPath = p.join(tempDir.path, 'import.json');

    try {
      final result = await Process.run(
        exporter,
        [inputPath, jsonPath],
        runInShell: false,
      );

      if (result.exitCode != 0) {
        final err = '${result.stderr}'.trim();
        throw StateError(
          err.isEmpty ? 'FuGrade.exe thoát với mã ${result.exitCode}' : err,
        );
      }

      final jsonStr = await File(jsonPath).readAsString(encoding: utf8);
      final Map<String, dynamic> data = jsonDecode(jsonStr);

      // Verify the password hash (supports both MD5 and plain text for backward compatibility)
      final expectedHash = data['password'] as String? ?? '';
      final inputPassword = password.isEmpty ? '1' : password;
      final inputHash = md5.convert(utf8.encode(inputPassword)).toString();

      final matchesMd5 = inputHash == expectedHash;
      final matchesPlainText = inputPassword == expectedHash;

      if (expectedHash.isNotEmpty && !matchesMd5 && !matchesPlainText) {
        throw ArgumentError('Mật khẩu không chính xác');
      }

      final studentsData = data['students'] as List<dynamic>? ?? [];
      final List<ThesisStudent> students = studentsData.map((s) {
        final Map<String, dynamic> smap = s as Map<String, dynamic>;
        return ThesisStudent(
          roll: smap['roll'] as String? ?? '',
          name: smap['name'] as String? ?? '',
          agreeToDefense: smap['agreeToDefense'] as String? ?? '',
          revisedForSecondDefense: smap['revisedForSecondDefense'] as String? ?? '',
          disagreeToDefense: smap['disagreeToDefense'] as String? ?? '',
          note: smap['note'] as String? ?? '',
        );
      }).toList();

      return ThesisComment(
        teacher: data['teacher'] as String? ?? '',
        dt: data['dt'] as String? ?? '',
        subjectCode: data['subjectCode'] as String? ?? '',
        className: data['className'] as String? ?? '',
        semester: data['semester'] as String? ?? '',
        password: expectedHash,
        titleVn: data['titleVn'] as String? ?? '',
        titleEn: data['titleEn'] as String? ?? '',
        content: data['content'] as String? ?? '',
        form: data['form'] as String? ?? '',
        attitude: data['attitude'] as String? ?? '',
        achievement: data['achievement'] as String? ?? '',
        limitation: data['limitation'] as String? ?? '',
        conclusion: data['conclusion'] as String? ?? '',
        students: students,
      );
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }
}
