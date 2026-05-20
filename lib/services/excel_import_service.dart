import 'package:excel/excel.dart';

import '../models/de_tai_meta.dart';
import '../models/thesis_comment.dart';
import '../models/tieu_chi_row.dart';

class ExcelImportService {
  static const _rollHeaders = {'roll', 'mssv', 'ma sv', 'ma sinh vien'};
  static const _nameHeaders = {'name', 'ten', 'ho ten', 'sinh vien', 'ten sinh vien'};

  static const _titleVnHeaders = {
    'ten khoa luan tieng viet',
    'title vn',
    'titlevn',
  };
  static const _titleEnHeaders = {
    'ten khoa luan tieng anh',
    'title en',
    'titleen',
  };
  static const _contentHeaders = {
    'noi dung khoa luan/ thesis content',
    'noi dung khoa luan',
    'thesis content',
    'content',
    'noi dung',
  };
  static const _formHeaders = {'hinh thuc khoa luan', 'form', 'hinh thuc'};
  static const _attitudeHeaders = {'thai do cua sinh vien', 'thai do', 'attitude'};
  static const _achievementHeaders = {'muc do dat', 'achievement', 'muc do'};
  static const _limitationHeaders = {'han che', 'limitation'};
  static const _conclusionHeaders = {'ket luan', 'conclusion'};

  static const _teacherHeaders = {'teacher', 'giang vien', 'nguoi danh gia'};
  static const _subjectHeaders = {'subjectcode', 'ma mon', 'subject code'};
  static const _classHeaders = {'classname', 'class name', 'ma lop', 'lop'};
  static const _semesterHeaders = {'semester', 'hoc ky', 'ky hoc'};
  static const _passwordHeaders = {'password', 'mat khau'};

  static const _tieuChiHeaders = {
    'tieu chi',
    'tieuchi',
    'tieu_chi',
    'criteria',
    'tieu chí',
    'tiêu chí',
    'tieu chí đánh giá',
  };

  static const _noiDungHeaders = {
    'noi dung',
    'nội dung',
    'mo ta',
    'mô tả',
    'content',
    'ghi chu ngan',
    'nội dung đề tài',
    'noi dung de tai',
  };

  static const _diemHeaders = {
    'diem',
    'điểm',
    'score',
    'danh gia',
    'đánh giá',
  };

  static const _ghiChuHeaders = {
    'ghi chu',
    'ghi chú',
    'note',
    'nhan xet ngan',
    'nhận xét ngắn',
  };

  static const _metaLabels = {
    'ten de tai',
    'tên đề tài',
    'de tai',
    'đề tài',
    'ten sinh vien',
    'tên sinh viên',
    'sinh vien',
    'sinh viên',
    'ma lop',
    'mã lớp',
    'lop',
    'lớp',
    'nguoi danh gia',
    'người đánh giá',
    'giang vien',
    'giảng viên',
  };

  ({ThesisComment? thesis, DeTaiMeta meta, List<TieuChiRow> rows, String? error})
      decodeBytes(List<int> bytes) {
    try {
      final excel = Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) {
        return (
          thesis: null,
          meta: const DeTaiMeta(),
          rows: [],
          error: 'File không có sheet.',
        );
      }
      final sheet = excel.tables.values.first;
      if (sheet.rows.isEmpty) {
        return (
          thesis: null,
          meta: const DeTaiMeta(),
          rows: [],
          error: 'Sheet trống.',
        );
      }

      final rawRows = sheet.rows;
      final headerIndex = _findThesisHeaderRow(rawRows);
      if (headerIndex != null) {
        return _decodeThesisGroup(rawRows, headerIndex);
      }

      return (
        thesis: null,
        meta: const DeTaiMeta(),
        rows: [],
        error:
            'Không tìm thấy dòng tiêu đề có cột Roll và Name.\n\n'
            'File của bạn chỉ cần các cột:\n'
            'Roll, Name, Tên KL (VN/EN), Nội dung, Hình thức, Thái độ, Mức độ đạt, Hạn chế.\n\n'
            'Đã đọc được:\n${_headerPreview(rawRows)}',
      );
    } catch (e) {
      return (
        thesis: null,
        meta: const DeTaiMeta(),
        rows: [],
        error: 'Không đọc được file Excel: $e',
      );
    }
  }

  int? _findThesisHeaderRow(List<List<Data?>> rawRows) {
    for (var i = 0; i < rawRows.length; i++) {
      if (_findRollColumn(rawRows[i]) != null && _findNameColumn(rawRows[i]) != null) {
        return i;
      }
    }
    return null;
  }

  int? _findRollColumn(List<Data?> row) {
    for (var c = 0; c < row.length; c++) {
      if (_isRollHeader(_normalize(_cellString(row, c)))) return c;
    }
    return null;
  }

  int? _findNameColumn(List<Data?> row) {
    for (var c = 0; c < row.length; c++) {
      if (_isNameHeader(_normalize(_cellString(row, c)))) return c;
    }
    return null;
  }

  bool _isRollHeader(String t) {
    if (t.isEmpty) return false;
    return _rollHeaders.contains(t) || t == 'roll' || t.contains('roll');
  }

  bool _isNameHeader(String t) {
    if (t.isEmpty) return false;
    if (t == 'name' || t == 'ho ten' || t == 'ten sinh vien') return true;
    if (t.contains('khoa luan') || t.contains('tieng')) return false;
    return t == 'ten';
  }

  String _headerPreview(List<List<Data?>> rawRows) {
    final lines = <String>[];
    for (var i = 0; i < rawRows.length && i < 3; i++) {
      final cells = <String>[];
      for (var c = 0; c < rawRows[i].length; c++) {
        final v = _cellString(rawRows[i], c);
        if (v.isNotEmpty) cells.add(v);
      }
      if (cells.isNotEmpty) {
        lines.add('Dòng ${i + 1}: ${cells.join(' | ')}');
      }
    }
    return lines.isEmpty ? '(trống)' : lines.join('\n');
  }

  ({ThesisComment? thesis, DeTaiMeta meta, List<TieuChiRow> rows, String? error})
      _decodeThesisGroup(List<List<Data?>> rawRows, int headerIndex) {
    final headerRow = rawRows[headerIndex];

    final colRoll = _findRollColumn(headerRow);
    final colName = _findNameColumn(headerRow);
    if (colRoll == null || colName == null) {
      return (
        thesis: null,
        meta: const DeTaiMeta(),
        rows: [],
        error: 'Thiếu cột Roll hoặc Name.',
      );
    }

    final colTitleVn = _findColumn(headerRow, _titleVnHeaders) ??
        _findColumnContains(headerRow, ['tieng viet', 'khoa luan vn']);
    final colTitleEn = _findColumn(headerRow, _titleEnHeaders) ??
        _findColumnContains(headerRow, ['tieng anh', 'khoa luan en']);
    final colContent = _findColumn(headerRow, _contentHeaders) ??
        _findColumnContains(headerRow, ['noi dung khoa luan', 'thesis content']);
    final colForm = _findColumn(headerRow, _formHeaders) ??
        _findColumnContains(headerRow, ['hinh thuc khoa luan']);
    final colAttitude = _findColumn(headerRow, _attitudeHeaders) ??
        _findColumnContains(headerRow, ['thai do']);
    final colAchievement = _findColumn(headerRow, _achievementHeaders) ??
        _findColumnContains(headerRow, ['muc do dat']);
    final colLimitation = _findColumn(headerRow, _limitationHeaders) ??
        _findColumnContains(headerRow, ['han che']);
    final colConclusion = _findColumn(headerRow, _conclusionHeaders);

    var teacher = '';
    var subjectCode = '';
    var className = '';
    var semester = '';
    var password = '';
    var conclusion = '';

    for (var i = 0; i < headerIndex; i++) {
      final row = rawRows[i];
      for (var c = 0; c < row.length; c++) {
        final label = _normalize(_cellString(row, c));
        final value = _cellAtOrNext(row, c);
        if (value.isEmpty) continue;
        if (_teacherHeaders.contains(label)) teacher = value;
        if (_subjectHeaders.contains(label)) subjectCode = value;
        if (_classHeaders.contains(label)) className = value;
        if (_semesterHeaders.contains(label)) semester = value;
        if (_passwordHeaders.contains(label)) password = value;
        if (_conclusionHeaders.contains(label)) conclusion = value;
      }
    }

    var titleVn = '';
    var titleEn = '';
    var content = '';
    var form = '';
    var attitude = '';
    var achievement = '';
    var limitation = '';

    final students = <ThesisStudent>[];

    for (var r = headerIndex + 1; r < rawRows.length; r++) {
      final row = rawRows[r];
      final roll = _cellString(row, colRoll);
      final name = _cellString(row, colName);
      if (roll.isEmpty && name.isEmpty) continue;

      titleVn = _carryForward(titleVn, _optionalCell(row, colTitleVn));
      titleEn = _carryForward(titleEn, _optionalCell(row, colTitleEn));
      content = _carryForward(content, _optionalCell(row, colContent));
      form = _carryForward(form, _optionalCell(row, colForm));
      attitude = _carryForward(attitude, _optionalCell(row, colAttitude));
      achievement = _carryForward(achievement, _optionalCell(row, colAchievement));
      limitation = _carryForward(limitation, _optionalCell(row, colLimitation));
      conclusion = _carryForward(conclusion, _optionalCell(row, colConclusion));

      if (roll.isNotEmpty || name.isNotEmpty) {
        students.add(ThesisStudent(roll: roll, name: name));
      }
    }

    if (students.isEmpty) {
      return (
        thesis: null,
        meta: const DeTaiMeta(),
        rows: [],
        error: 'Không có dòng sinh viên hợp lệ sau header.',
      );
    }

    final thesis = ThesisComment(
      teacher: teacher,
      subjectCode: subjectCode,
      className: className,
      semester: semester,
      password: password,
      titleVn: titleVn,
      titleEn: titleEn,
      content: content,
      form: form,
      attitude: attitude,
      achievement: achievement,
      limitation: limitation,
      conclusion: conclusion,
      students: students,
    );

    return (thesis: thesis, meta: const DeTaiMeta(), rows: [], error: null);
  }

  ({ThesisComment? thesis, DeTaiMeta meta, List<TieuChiRow> rows, String? error})
      _decodeCriteriaFormat(List<List<Data?>> rawRows) {
    var i = 0;
    var meta = const DeTaiMeta();

    while (i < rawRows.length) {
      final label = _cellString(rawRows[i], 0);
      final value = _cellString(rawRows[i], 1);
      final norm = _normalize(label);
      if (label.isEmpty && value.isEmpty) {
        i++;
        continue;
      }
      if (_looksLikeHeaderRow(rawRows[i])) break;
      if (_metaLabels.contains(norm) || _isMetaPair(label, value)) {
        meta = _mergeMeta(meta, norm, value);
        i++;
        continue;
      }
      if (label.isNotEmpty && value.isNotEmpty && !_isLikelyTieuChiLabel(norm)) {
        meta = _mergeMeta(meta, norm, value);
        i++;
        continue;
      }
      break;
    }

    if (i >= rawRows.length) {
      return (
        thesis: null,
        meta: meta,
        rows: [],
        error: 'Không tìm thấy dòng tiêu đề bảng (Roll/Name hoặc Tiêu chí).',
      );
    }

    final headerRow = rawRows[i];
    final colTieuChi = _findColumn(headerRow, _tieuChiHeaders);
    if (colTieuChi == null) {
      return (
        thesis: null,
        meta: meta,
        rows: [],
        error:
            'Không nhận diện được định dạng Excel.\n'
            '• Nhóm khóa luận: cần cột Roll và Name.\n'
            '• Hoặc bảng tiêu chí: cần cột Tiêu chí.',
      );
    }

    final colNoiDung = _findColumn(headerRow, _noiDungHeaders) ?? colTieuChi + 1;
    final colDiem = _findColumn(headerRow, _diemHeaders);
    final colGhiChu = _findColumn(headerRow, _ghiChuHeaders);

    final out = <TieuChiRow>[];
    for (var r = i + 1; r < rawRows.length; r++) {
      final row = rawRows[r];
      final tc = _cellString(row, colTieuChi);
      final nd = _cellString(row, colNoiDung);
      final gc = colGhiChu != null ? _cellString(row, colGhiChu) : '';
      final diem = colDiem != null ? _parseDoubleFromCell(row[colDiem]) : null;
      final tcr = TieuChiRow(tieuChi: tc, noiDung: nd, diem: diem, ghiChu: gc);
      if (!tcr.isEmpty) out.add(tcr);
    }

    if (out.isEmpty) {
      return (
        thesis: null,
        meta: meta,
        rows: [],
        error: 'Không có dòng tiêu chí hợp lệ sau header.',
      );
    }
    return (thesis: null, meta: meta, rows: out, error: null);
  }

  String _carryForward(String current, String next) {
    return next.isNotEmpty ? next : current;
  }

  String _optionalCell(List<Data?> row, int? col) {
    if (col == null) return '';
    return _cellString(row, col);
  }

  String _cellAtOrNext(List<Data?> row, int labelCol) {
    final direct = _cellString(row, labelCol + 1);
    if (direct.isNotEmpty) return direct;
    for (var c = labelCol + 1; c < row.length; c++) {
      final v = _cellString(row, c);
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  int? _findColumnContains(List<Data?> headerRow, List<String> needles) {
    for (var c = 0; c < headerRow.length; c++) {
      final t = _normalize(_cellString(headerRow, c));
      for (final n in needles) {
        if (t.contains(n)) return c;
      }
    }
    return null;
  }

  bool _isMetaPair(String label, String value) {
    return label.isNotEmpty &&
        value.isNotEmpty &&
        !_looksLikeHeaderRowFromStrings(label, value);
  }

  bool _isLikelyTieuChiLabel(String norm) => _tieuChiHeaders.contains(norm);

  DeTaiMeta _mergeMeta(DeTaiMeta m, String normLabel, String value) {
    if (value.isEmpty) return m;
    if (const {'ten de tai', 'tên đề tài', 'de tai', 'đề tài'}.contains(normLabel)) {
      return DeTaiMeta(
        tenDeTai: value,
        tenSinhVien: m.tenSinhVien,
        maLop: m.maLop,
        nguoiDanhGia: m.nguoiDanhGia,
      );
    }
    if (const {'ten sinh vien', 'tên sinh viên', 'sinh vien', 'sinh viên'}
        .contains(normLabel)) {
      return DeTaiMeta(
        tenDeTai: m.tenDeTai,
        tenSinhVien: value,
        maLop: m.maLop,
        nguoiDanhGia: m.nguoiDanhGia,
      );
    }
    if (const {'ma lop', 'mã lớp', 'lop', 'lớp'}.contains(normLabel)) {
      return DeTaiMeta(
        tenDeTai: m.tenDeTai,
        tenSinhVien: m.tenSinhVien,
        maLop: value,
        nguoiDanhGia: m.nguoiDanhGia,
      );
    }
    if (const {'nguoi danh gia', 'người đánh giá', 'giang vien', 'giảng viên'}
        .contains(normLabel)) {
      return DeTaiMeta(
        tenDeTai: m.tenDeTai,
        tenSinhVien: m.tenSinhVien,
        maLop: m.maLop,
        nguoiDanhGia: value,
      );
    }
    return m;
  }

  bool _looksLikeHeaderRow(List<Data?> row) {
    return _looksLikeHeaderRowFromStrings(_cellString(row, 0), _cellString(row, 1));
  }

  bool _looksLikeHeaderRowFromStrings(String a, String b) {
    final na = _normalize(a);
    final nb = _normalize(b);
    if (_tieuChiHeaders.contains(na) || _tieuChiHeaders.contains(nb)) return true;
    if (_rollHeaders.contains(na) || _rollHeaders.contains(nb)) return true;
    if (_noiDungHeaders.contains(na) || _noiDungHeaders.contains(nb)) return true;
    return false;
  }

  int? _findColumn(List<Data?> headerRow, Set<String> keys) {
    for (var c = 0; c < headerRow.length; c++) {
      final t = _normalize(_cellString(headerRow, c));
      if (keys.contains(t)) return c;
    }
    return null;
  }

  String _cellString(List<Data?> row, int col) {
    if (col < 0 || col >= row.length) return '';
    return _stringFromCellValue(row[col]?.value).trim();
  }

  String _stringFromCellValue(CellValue? v) {
    if (v == null) return '';
    return switch (v) {
      TextCellValue(:final value) => _flattenTextSpan(value),
      FormulaCellValue(:final formula) => formula,
      IntCellValue(:final value) => value.toString(),
      DoubleCellValue(:final value) => value.toString(),
      BoolCellValue(:final value) => value ? 'Có' : 'Không',
      DateCellValue(:final year, :final month, :final day) =>
        DateTime(year, month, day).toIso8601String().split('T').first,
      DateTimeCellValue dt => dt.asDateTimeLocal().toIso8601String(),
      TimeCellValue t => t.toString(),
    };
  }

  String _flattenTextSpan(TextSpan span) {
    final b = StringBuffer();
    if (span.text != null) b.write(span.text);
    final children = span.children;
    if (children != null) {
      for (final c in children) {
        b.write(_flattenTextSpan(c));
      }
    }
    return b.toString();
  }

  double? _parseDoubleFromCell(Data? cell) {
    final v = cell?.value;
    if (v == null) return null;
    return switch (v) {
      IntCellValue(:final value) => value.toDouble(),
      DoubleCellValue(:final value) => value,
      TextCellValue(:final value) =>
        double.tryParse(_flattenTextSpan(value).trim().replaceAll(',', '.')),
      FormulaCellValue(:final formula) =>
        double.tryParse(formula.trim().replaceAll(',', '.')),
      BoolCellValue(:final value) => value ? 1.0 : 0.0,
      _ => null,
    };
  }

  String _normalize(String s) {
    var t = s.replaceAll('\u00a0', ' ').toLowerCase().trim();
    const map = {
      'á': 'a', 'à': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
      'ă': 'a', 'ắ': 'a', 'ằ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
      'â': 'a', 'ấ': 'a', 'ầ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
      'đ': 'd',
      'é': 'e', 'è': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
      'ê': 'e', 'ế': 'e', 'ề': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
      'í': 'i', 'ì': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
      'ó': 'o', 'ò': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
      'ô': 'o', 'ố': 'o', 'ồ': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
      'ơ': 'o', 'ớ': 'o', 'ờ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
      'ú': 'u', 'ù': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
      'ư': 'u', 'ứ': 'u', 'ừ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
      'ý': 'y', 'ỳ': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
    };
    final buf = StringBuffer();
    for (final ch in t.runes) {
      final c = String.fromCharCode(ch);
      buf.write(map[c] ?? c);
    }
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ');
  }
}
