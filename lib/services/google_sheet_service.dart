import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../models/de_tai_record.dart';

class SheetImportResult {
  const SheetImportResult({
    this.topics = const [],
    this.error,
    this.sourceLabel,
    this.columnSummary,
  });

  final List<DeTaiRecord> topics;
  final String? error;
  final String? sourceLabel;
  final String? columnSummary;
}

class GoogleSheetService {
  static const _maDeTaiHeaders = {
    'ma de tai',
    'ma dt',
    'made tai',
    'topic code',
    'ma de tai kl',
  };
  static const _maNhomHeaders = {
    'ma nhom',
    'manhom',
    'group',
    'group code',
    'ma nhom kl',
    'ma nhom khoa luan',
    'nhom',
    'class',
  };
  static const _titleEnHeaders = {
    'ten de tai tieng anh',
    'ten de tai (tieng anh)',
    'ten kl tieng anh',
    'ten kl (en)',
    'ten kl en',
    'ten en',
    'title en',
    'titleen',
    'tieu de tieng anh',
    'tieu de en',
  };
  static const _titleVnHeaders = {
    'ten de tai tieng viet',
    'de tai tieng viet',
    'ten de tai (tieng viet)',
    'ten kl tieng viet',
    'ten kl (vn)',
    'ten kl vn',
    'ten vn',
    'title vn',
    'titlevn',
    'tieu de tieng viet',
    'tieu de vn',
    'ten de tai',
    'ten khoa luan',
  };
  static const _contentHeaders = {
    'noi dung khoa luan',
    'noi dung khóa luận',
    'thesis content',
    'noi dung',
  };
  static const _formHeaders = {
    'hinh thuc khoa luan',
    'hinh thuc',
    'form',
  };
  static const _attitudeHeaders = {
    'thai do cua sinh vien',
    'thai do',
    'attitude',
  };
  static const _achievementHeaders = {
    'muc do dat duoc so voi muc tieu',
    'muc do dat',
    'achievement',
    'muc do dat duoc',
  };
  static const _limitationHeaders = {
    'han che',
    'limitation',
    'han che cua khoa luan',
  };
  static const _danhGiaHeaders = {
    'danh gia theo goc nhin sv',
    'danh gia',
    'danh gia sv',
  };
  static const _nhanXetHeaders = {
    'nhan xet theo goc nhin sv',
    'nhan xet sv',
    'nhan xet',
    'nhan xet chung',
    'comment',
    'feedback',
  };

  SheetImportResult parseDelimitedText(String text, {String sourceLabel = 'test'}) =>
      _parseDelimited(text, sourceLabel: sourceLabel);

  Future<SheetImportResult> importFromUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return const SheetImportResult(error: 'Chưa nhập link Google Sheet.');
    }
    final exportUrl = _toExportCsvUrl(trimmed);
    if (exportUrl == null) {
      return const SheetImportResult(
        error: 'Link không hợp lệ. Dán link dạng docs.google.com/spreadsheets/...',
      );
    }
    try {
      final response = await http.get(Uri.parse(exportUrl));
      if (response.statusCode != 200) {
        return SheetImportResult(
          error:
              'Không tải được sheet (HTTP ${response.statusCode}). '
              'Bật quyền "Anyone with the link can view".',
        );
      }
      final csv = utf8.decode(response.bodyBytes, allowMalformed: true);
      return _parseDelimited(csv, sourceLabel: trimmed);
    } catch (e) {
      return SheetImportResult(error: 'Lỗi tải Google Sheet: $e');
    }
  }

  Future<SheetImportResult> pickLocalSheet() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
      withData: true,
    );
    if (r == null || r.files.isEmpty) return const SheetImportResult();
    final f = r.files.single;
    final bytes = f.bytes;
    if (bytes == null) {
      return SheetImportResult(error: 'Không đọc được file.', sourceLabel: f.name);
    }
    final name = f.name.toLowerCase();
    if (name.endsWith('.xlsx')) {
      return _parseXlsx(bytes, sourceLabel: f.name);
    }
    final text = utf8.decode(bytes, allowMalformed: true);
    return _parseDelimited(text, sourceLabel: f.name);
  }

  String? _toExportCsvUrl(String url) {
    final idMatch = RegExp(
      r'/spreadsheets/d/([a-zA-Z0-9-_]+)',
    ).firstMatch(url);
    if (idMatch == null) return null;
    final id = idMatch.group(1)!;
    var gid = '0';
    final gidMatch = RegExp(r'[#&?]gid=(\d+)').firstMatch(url);
    if (gidMatch != null) gid = gidMatch.group(1)!;
    return 'https://docs.google.com/spreadsheets/d/$id/export?format=csv&gid=$gid';
  }

  SheetImportResult _parseXlsx(List<int> bytes, {required String sourceLabel}) {
    try {
      final excel = Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) {
        return const SheetImportResult(error: 'File Excel trống.');
      }
      final rows = excel.tables.values.first.rows;
      final lines = <String>[];
      for (final row in rows) {
        final cells = <String>[];
        for (var c = 0; c < row.length; c++) {
          cells.add(_cellString(row, c));
        }
        lines.add(_joinCsvRow(cells));
      }
      return _parseDelimited(lines.join('\n'), sourceLabel: sourceLabel);
    } catch (e) {
      return SheetImportResult(error: 'Lỗi đọc Excel: $e');
    }
  }

  SheetImportResult _parseDelimited(String text, {required String sourceLabel}) {
    final rows = _parseCsvRows(text);
    if (rows.isEmpty) {
      return const SheetImportResult(error: 'Sheet trống.');
    }
    final headerIndex = _findHeaderIndex(rows);
    if (headerIndex == null) {
      return const SheetImportResult(error: 'Không tìm thấy header sheet.');
    }
    final header = rows[headerIndex];
    final cols = _mapColumns(header);
    final colMaDeTai = cols['maDeTai'];
    final colMaNhom = cols['maNhom'];
    final colTitleEn = cols['titleEn'];
    final colTitleVn = cols['titleVn'];
    final colContent = cols['content'];
    final colForm = cols['form'];
    final colAttitude = cols['attitude'];
    final colAchievement = cols['achievement'];
    final colLimitation = cols['limitation'];
    final colDanhGia = cols['danhGia'];
    final colNhanXet = cols['nhanXet'];

    if (colMaNhom == null) {
      return const SheetImportResult(error: 'Thiếu cột Ma nhom.');
    }

    final summary = _columnSummary(header, cols);

    final topics = <DeTaiRecord>[];
    for (var r = headerIndex + 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.every((c) => c.trim().isEmpty)) continue;
      final maNhom = _cell(row, colMaNhom);
      final maDeTai = colMaDeTai != null ? _cell(row, colMaDeTai) : '';
      final titleEn = colTitleEn != null ? _cell(row, colTitleEn) : '';
      final titleVn = colTitleVn != null ? _cell(row, colTitleVn) : '';
      final danhGia = colDanhGia != null ? _cell(row, colDanhGia) : '';
      final nhanXet = colNhanXet != null ? _cell(row, colNhanXet) : '';
      if (maNhom.isEmpty && maDeTai.isEmpty && titleVn.isEmpty) continue;

      final record = DeTaiRecord();
      record.applySheetFields(
        maDeTai: maDeTai,
        maNhom: maNhom,
        titleEn: titleEn,
        titleVn: titleVn,
        content: colContent != null ? _cell(row, colContent) : '',
        form: colForm != null ? _cell(row, colForm) : '',
        attitude: colAttitude != null ? _cell(row, colAttitude) : '',
        achievement: colAchievement != null ? _cell(row, colAchievement) : '',
        limitation: colLimitation != null ? _cell(row, colLimitation) : '',
        danhGia: danhGia,
        nhanXetSv: nhanXet,
      );
      topics.add(record);
    }

    if (topics.isEmpty) {
      return const SheetImportResult(error: 'Không có dòng đề tài hợp lệ.');
    }
    return SheetImportResult(
      topics: topics,
      sourceLabel: sourceLabel,
      columnSummary: summary,
    );
  }

  Map<String, int?> _mapColumns(List<String> header) {
    final used = <int>{};
    int? pick(Set<String> keys) {
      var bestCol = -1;
      var bestScore = 0;
      for (var c = 0; c < header.length; c++) {
        if (used.contains(c)) continue;
        final t = _normalize(header[c]);
        if (t.isEmpty) continue;
        for (final k in keys) {
          final score = t == k ? 1000 + k.length : (t.contains(k) ? k.length : 0);
          if (score > bestScore) {
            bestScore = score;
            bestCol = c;
          }
        }
      }
      if (bestCol < 0) return null;
      used.add(bestCol);
      return bestCol;
    }

    return {
      'maDeTai': pick(_maDeTaiHeaders),
      'maNhom': pick(_maNhomHeaders),
      'titleVn': pick(_titleVnHeaders),
      'titleEn': pick(_titleEnHeaders),
      'content': pick(_contentHeaders),
      'form': pick(_formHeaders),
      'attitude': pick(_attitudeHeaders),
      'achievement': pick(_achievementHeaders),
      'limitation': pick(_limitationHeaders),
      'danhGia': pick(_danhGiaHeaders),
      'nhanXet': pick(_nhanXetHeaders),
    };
  }

  String _columnSummary(List<String> header, Map<String, int?> cols) {
    String label(String key, int? col) {
      if (col == null) return '$key: —';
      final h = col < header.length ? header[col].trim() : '';
      return '$key: ${h.isEmpty ? "cột ${col + 1}" : h}';
    }
    return [
      label('Mã đề tài', cols['maDeTai']),
      label('Mã nhóm', cols['maNhom']),
      label('Tên VN', cols['titleVn']),
      label('Nội dung KL', cols['content']),
      label('Hình thức', cols['form']),
      label('Thái độ', cols['attitude']),
      label('Mức độ đạt', cols['achievement']),
      label('Hạn chế', cols['limitation']),
    ].join(' · ');
  }

  List<List<String>> _parseCsvRows(String text) {
    final rows = <List<String>>[];
    final lines = const LineSplitter().convert(text.replaceAll('\r\n', '\n'));
    String? delimiter;
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      delimiter ??= _detectDelimiter(line);
      rows.add(_splitDelimitedLine(line, delimiter));
    }
    return rows;
  }

  String _detectDelimiter(String line) {
    var tabs = 0;
    var commas = 0;
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (!inQuotes) {
        if (ch == '\t') tabs++;
        if (ch == ',') commas++;
      }
    }
    return tabs > commas ? '\t' : ',';
  }

  List<String> _splitDelimitedLine(String line, String delimiter) {
    final out = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == delimiter && !inQuotes) {
        out.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    out.add(buf.toString());
    return out;
  }

  String _joinCsvRow(List<String> cells) {
    return cells
        .map((c) {
          if (c.contains(',') || c.contains('"') || c.contains('\n')) {
            return '"${c.replaceAll('"', '""')}"';
          }
          return c;
        })
        .join(',');
  }

  int? _findHeaderIndex(List<List<String>> rows) {
    for (var i = 0; i < rows.length; i++) {
      if (_mapColumns(rows[i])['maNhom'] != null) return i;
    }
    return null;
  }

  String _cell(List<String> row, int col) {
    if (col < 0 || col >= row.length) return '';
    return row[col].trim();
  }

  String _cellString(List<Data?> row, int col) {
    if (col < 0 || col >= row.length) return '';
    final v = row[col]?.value;
    if (v == null) return '';
    return switch (v) {
      TextCellValue(:final value) => _flattenText(value),
      IntCellValue(:final value) => value.toString(),
      DoubleCellValue(:final value) => value.toString(),
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
