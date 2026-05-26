import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/thesis_comment.dart';

class CmtExportService {
  static const _exeNames = ['CmtSerialize.exe', 'FuGrade.exe'];

  String? locateSerializer() {
    final candidates = <String>[];
    final exe = Platform.resolvedExecutable;
    final exeDir = p.dirname(exe);
    for (final name in _exeNames) {
      candidates.add(p.join(exeDir, name));
    }

    final cwd = Directory.current.path;
    for (final name in _exeNames) {
      candidates.add(p.join(cwd, name));
      candidates.add(
        p.join(cwd, 'tools', 'cmt_exporter', 'bin', 'Release', 'net48', name),
      );
    }

    final script = Platform.script.toFilePath();
    if (script.isNotEmpty) {
      var dir = p.dirname(script);
      for (var i = 0; i < 6; i++) {
        for (final name in _exeNames) {
          candidates.add(
            p.join(dir, 'tools', 'cmt_exporter', 'bin', 'Release', 'net48', name),
          );
        }
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
    final serializer = locateSerializer();
    if (serializer == null) {
      throw StateError('Không tìm thấy CmtSerialize.exe / FuGrade.exe.');
    }

    final tempDir = await Directory.systemTemp.createTemp('excel_cmt_');
    final jsonPath = p.join(tempDir.path, 'export.json');
    final outPath = p.join(tempDir.path, 'out.cmt');

    try {
      await File(jsonPath).writeAsString(
        jsonEncode(thesis.toExportJson()),
        encoding: utf8,
      );

      final result = await Process.run(
        serializer,
        [jsonPath, outPath],
        runInShell: false,
      );

      if (result.exitCode != 0) {
        final err = '${result.stderr}'.trim();
        throw StateError(
          err.isEmpty ? 'Xuất .cmt thất bại (mã ${result.exitCode})' : err,
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

  Future<ThesisComment> importFromFile(String cmtPath) async {
    final serializer = locateSerializer();
    if (serializer == null) {
      throw StateError('Không tìm thấy CmtSerialize.exe / FuGrade.exe.');
    }

    final tempDir = await Directory.systemTemp.createTemp('excel_cmt_');
    final jsonPath = p.join(tempDir.path, 'import.json');

    try {
      final result = await Process.run(
        serializer,
        ['--read-json', cmtPath, jsonPath],
        runInShell: false,
      );

      if (result.exitCode != 0) {
        final err = '${result.stderr}'.trim();
        throw StateError(
          err.isEmpty ? 'Đọc .cmt thất bại (mã ${result.exitCode})' : err,
        );
      }

      final text = await File(jsonPath).readAsString(encoding: utf8);
      final j = jsonDecode(text);
      if (j is! Map<String, dynamic>) {
        throw StateError('File .cmt không đúng định dạng.');
      }
      return ThesisComment.fromExportJson(j);
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }
}
