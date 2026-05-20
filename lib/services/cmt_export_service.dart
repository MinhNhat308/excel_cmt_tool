import 'dart:convert';
import 'dart:io';

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
      await File(jsonPath).writeAsString(
        jsonEncode(thesis.toExportJson()),
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
}
