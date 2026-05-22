import 'dart:convert';
import 'dart:io';

import '../models/project_bundle.dart';
import 'fg_fuge_crypto_service.dart';
import 'write_utf8_file.dart';

class ProjectStorageService {
  Future<void> saveJson(ProjectBundle bundle, String path) async {
    final full = path.toLowerCase().endsWith('.json') ? path : '$path.json';
    await writeUtf8File(
      full,
      const JsonEncoder.withIndent('  ').convert(bundle.toJson()),
    );
  }

  Future<ProjectBundle> loadJson(String path) async {
    final text = await File(path).readAsString(encoding: utf8);
    final j = jsonDecode(text) as Map<String, dynamic>;
    return ProjectBundle.fromJson(j);
  }

  Future<void> saveFg(ProjectBundle bundle, String path) async {
    final payload = bundle.roster?.fuGradePayload;
    if (payload == null) {
      throw StateError('Không có dữ liệu .fg để lưu. Import lại file .fg.');
    }
    final full = path.toLowerCase().endsWith('.fg') ? path : '$path.fg';
    final plain = const JsonEncoder().convert(payload);
    final bytes = FgFugeCryptoService().encryptFgBytes(plain);
    await File(full).writeAsBytes(bytes, flush: true);
  }
}
