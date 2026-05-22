import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import '../models/fg_roster.dart';
import 'fg_fuge_crypto_service.dart';
import 'fg_fuge_parser.dart';

class FgImportResult {
  const FgImportResult({this.roster, this.error, this.fileName});

  final FgRoster? roster;
  final String? error;
  final String? fileName;
}

class FgImportService {
  static const _groupHeaders = {
    'ma nhom',
    'manhom',
    'group',
    'group code',
    'ma nhom kl',
    'nhom',
  };
  static const _rollHeaders = {'roll', 'mssv', 'ma sv', 'ma sinh vien'};
  static const _nameHeaders = {'name', 'ten', 'ho ten', 'sinh vien'};

  Future<FgImportResult> pickAndImport() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['fg', 'json', 'xlsx'],
      withData: true,
    );
    if (r == null || r.files.isEmpty) {
      return const FgImportResult();
    }
    final f = r.files.single;
    final bytes = f.bytes;
    if (bytes == null) {
      return FgImportResult(error: 'Không đọc được nội dung file.', fileName: f.name);
    }
    return importBytes(bytes, f.name, path: f.path);
  }

  Future<FgImportResult> importBytes(
    List<int> bytes,
    String fileName, {
    String? path,
  }) async {
    final lower = fileName.toLowerCase();
    try {
      if (lower.endsWith('.json')) {
        final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final roster = FgRoster.fromJson(j);
        if (roster.students.isEmpty) {
          return FgImportResult(
            error: 'File JSON không có sinh viên.',
            fileName: fileName,
          );
        }
        return FgImportResult(
          roster: FgRoster(
            teacher: roster.teacher,
            subjectCode: roster.subjectCode,
            className: roster.className,
            semester: roster.semester,
            password: roster.password,
            students: roster.students,
            sourcePath: path ?? fileName,
          ),
          fileName: fileName,
        );
      }

      if (lower.endsWith('.xlsx')) {
        return _importXlsx(bytes, fileName, path);
      }

      if (lower.endsWith('.fg')) {
        return _importFuGradeFg(bytes, fileName, path);
      }

      return FgImportResult(
        error: 'Định dạng không hỗ trợ: $fileName',
        fileName: fileName,
      );
    } catch (e) {
      return FgImportResult(
        error: 'Lỗi đọc file FG: $e',
        fileName: fileName,
      );
    }
  }

  FgImportResult _importFuGradeFg(
    List<int> bytes,
    String fileName,
    String? path,
  ) {
    final crypto = FgFugeCryptoService();
    final parser = const FgFugeParser();
    try {
      final plain = crypto.decryptFgBytes(bytes);
      final root = jsonDecode(plain);
      if (root is! Map<String, dynamic>) {
        return FgImportResult(
          error: 'File .fg không đúng cấu trúc FuGrade (TeacherGrade).',
          fileName: fileName,
        );
      }
      if (root.containsKey('SubjectClassGrades')) {
        final roster = parser.parseTeacherGradeJson(
          root,
          sourcePath: path ?? fileName,
        );
        if (roster.students.isEmpty) {
          return FgImportResult(
            error: 'Không có sinh viên SEP trong file .fg.',
            fileName: fileName,
          );
        }
        return FgImportResult(roster: roster, fileName: fileName);
      }
      final flat = FgRoster.fromJson(root);
      if (flat.students.isEmpty) {
        return FgImportResult(
          error: 'File .fg/JSON không có sinh viên.',
          fileName: fileName,
        );
      }
      return FgImportResult(
        roster: FgRoster(
          teacher: flat.teacher,
          subjectCode: flat.subjectCode,
          className: flat.className,
          semester: flat.semester,
          password: flat.password,
          students: flat.students,
          sourcePath: path ?? fileName,
        ),
        fileName: fileName,
      );
    } catch (e) {
      return FgImportResult(
        error: 'Không đọc file .fg FuGrade: $e',
        fileName: fileName,
      );
    }
  }

  FgImportResult _importXlsx(List<int> bytes, String fileName, String? path) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return FgImportResult(error: 'File Excel trống.', fileName: fileName);
    }
    final sheet = excel.tables.values.first;
    if (sheet.rows.isEmpty) {
      return FgImportResult(error: 'Sheet trống.', fileName: fileName);
    }

    final rawRows = sheet.rows;
    final headerIndex = _findHeaderRow(rawRows);
    if (headerIndex == null) {
      return FgImportResult(
        error: 'Không tìm thấy cột Ma nhom + Roll/MSSV + Ten.',
        fileName: fileName,
      );
    }

    final header = rawRows[headerIndex];
    final colGroup = _findColumn(header, _groupHeaders);
    final colRoll = _findColumn(header, _rollHeaders);
    final colName = _findColumn(header, _nameHeaders);
    if (colGroup == null || colRoll == null || colName == null) {
      return FgImportResult(
        error: 'Cần cột: Ma nhom, Roll (MSSV), Ten.',
        fileName: fileName,
      );
    }

    var teacher = '';
    var subjectCode = '';
    var className = '';
    var semester = '';
    var password = '';

    for (var i = 0; i < headerIndex; i++) {
      final row = rawRows[i];
      for (var c = 0; c < row.length; c++) {
        final label = _normalize(_cellString(row, c));
        final value = _valueAfterLabel(row, c);
        if (value.isEmpty) continue;
        if (label.contains('teacher') || label.contains('giang vien')) {
          teacher = value;
        }
        if (label.contains('subject') || label.contains('ma mon')) {
          subjectCode = value;
        }
        if (label.contains('class') || label.contains('lop')) {
          className = value;
        }
        if (label.contains('semester') || label.contains('hoc ky')) {
          semester = value;
        }
        if (label.contains('password') || label.contains('mat khau')) {
          password = value;
        }
      }
    }

    final students = <FgStudent>[];
    for (var r = headerIndex + 1; r < rawRows.length; r++) {
      final row = rawRows[r];
      final group = _cellString(row, colGroup);
      final roll = _cellString(row, colRoll);
      final name = _cellString(row, colName);
      if (group.isEmpty && roll.isEmpty && name.isEmpty) continue;
      if (roll.isEmpty && name.isEmpty) continue;
      students.add(FgStudent(roll: roll, name: name, groupCode: group));
    }

    if (students.isEmpty) {
      return FgImportResult(
        error: 'Không có dòng sinh viên hợp lệ.',
        fileName: fileName,
      );
    }

    return FgImportResult(
      roster: FgRoster(
        teacher: teacher,
        subjectCode: subjectCode,
        className: className,
        semester: semester,
        password: password,
        students: students,
        sourcePath: path ?? fileName,
      ),
      fileName: fileName,
    );
  }

  int? _findHeaderRow(List<List<Data?>> rows) {
    for (var i = 0; i < rows.length; i++) {
      final g = _findColumn(rows[i], _groupHeaders);
      final roll = _findColumn(rows[i], _rollHeaders);
      final name = _findColumn(rows[i], _nameHeaders);
      if (g != null && roll != null && name != null) return i;
    }
    return null;
  }

  int? _findColumn(List<Data?> row, Set<String> keys) {
    for (var c = 0; c < row.length; c++) {
      final t = _normalize(_cellString(row, c));
      if (keys.contains(t)) return c;
      for (final k in keys) {
        if (t.contains(k)) return c;
      }
    }
    return null;
  }

  String _cellString(List<Data?> row, int col) {
    if (col < 0 || col >= row.length) return '';
    return _stringFromCell(row[col]?.value).trim();
  }

  String _valueAfterLabel(List<Data?> row, int labelCol) {
    for (var c = labelCol + 1; c < row.length; c++) {
      final v = _cellString(row, c);
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  String _stringFromCell(CellValue? v) {
    if (v == null) return '';
    return switch (v) {
      TextCellValue(:final value) => _flattenText(value),
      IntCellValue(:final value) => value.toString(),
      DoubleCellValue(:final value) => value.toString(),
      BoolCellValue(:final value) => value ? '1' : '0',
      FormulaCellValue(:final formula) => formula,
      _ => v.toString(),
    };
  }

  String _flattenText(TextSpan span) {
    final b = StringBuffer();
    if (span.text != null) b.write(span.text);
    final children = span.children;
    if (children != null) {
      for (final c in children) {
        b.write(_flattenText(c));
      }
    }
    return b.toString();
  }

  String _normalize(String s) {
    var t = s.replaceAll('\u00a0', ' ').toLowerCase().trim();
    const map = {
      'á': 'a', 'à': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
      'ă': 'a', 'â': 'a', 'đ': 'd',
      'é': 'e', 'è': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'ơ': 'o',
      'ú': 'u', 'ù': 'u', 'ư': 'u',
      'ý': 'y',
    };
    final buf = StringBuffer();
    for (final ch in t.runes) {
      final c = String.fromCharCode(ch);
      buf.write(map[c] ?? c);
    }
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ');
  }
}
