import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../models/de_tai_record.dart';
import '../models/project_bundle.dart';
import 'cmt_export_service.dart';

class BatchExportService {
  BatchExportService({CmtExportService? cmt}) : _cmt = cmt ?? CmtExportService();

  final CmtExportService _cmt;

  Future<void> exportOne(DeTaiRecord topic, String outputPath) async {
    if (topic.students.isEmpty) {
      throw StateError('Đề tài ${topic.maDeTai} chưa có sinh viên (mã nhóm không khớp FG).');
    }
    final thesis = topic.toThesisComment();
    await _cmt.exportToFile(thesis: thesis, outputPath: outputPath);
  }

  Future<int> exportAllToZip({
    required ProjectBundle bundle,
    required String zipPath,
  }) async {
    if (bundle.topics.isEmpty) {
      throw StateError('Không có đề tài để xuất.');
    }

    final tempDir = await Directory.systemTemp.createTemp('cmt_batch_');
    final archive = Archive();
    var ok = 0;
    final errors = <String>[];

    try {
      for (final topic in bundle.topics) {
        if (topic.students.isEmpty) {
          errors.add('${topic.maDeTai}: không có SV');
          continue;
        }
        final safeName = _safeFileName(
          topic.maDeTai.isNotEmpty ? topic.maDeTai : topic.maNhom,
        );
        final cmtPath = p.join(tempDir.path, '$safeName.cmt');
        try {
          await exportOne(topic, cmtPath);
          final bytes = await File(cmtPath).readAsBytes();
          archive.addFile(ArchiveFile('$safeName.cmt', bytes.length, bytes));
          ok++;
        } catch (e) {
          errors.add('$safeName: $e');
        }
      }

      if (ok == 0) {
        throw StateError(errors.join('\n'));
      }

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        throw StateError('Không tạo được file nén.');
      }
      final full =
          zipPath.toLowerCase().endsWith('.zip') ? zipPath : '$zipPath.zip';
      await File(full).writeAsBytes(zipBytes, flush: true);

      if (errors.isNotEmpty) {
        throw StateError(
          'Đã xuất $ok/${bundle.topics.length} đề tài.\n${errors.join('\n')}',
        );
      }
      return ok;
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  String _safeFileName(String name) {
    var s = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    if (s.isEmpty) s = 'de_tai';
    return s.length > 80 ? s.substring(0, 80) : s;
  }
}
