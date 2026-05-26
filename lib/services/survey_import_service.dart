import 'package:excel_plus/excel_plus.dart';

/// Đại diện một dòng dữ liệu khảo sát từ 1 sinh viên hoặc 1 nhóm
class SurveyRow {
  final String roll;        // Roll_number / MSSV
  final String fullname;    // Fullname
  final String email;       // Email
  final String groupCode;   // Group_code
  final String topicCode;   // Topic_code
  final String titleVn;     // Topic_title(Vietnamese)
  final String titleEn;     // Topic_title(English)
  final String studentEval; // Student_evaluation
  
  // Fields for Teacher Evaluation Sheet
  final String content;
  final String form;
  final String attitude;
  final String achievement;
  final String limitation;

  const SurveyRow({
    this.roll = '',
    this.fullname = '',
    this.email = '',
    this.groupCode = '',
    this.topicCode = '',
    this.titleVn = '',
    this.titleEn = '',
    this.studentEval = '',
    this.content = '',
    this.form = '',
    this.attitude = '',
    this.achievement = '',
    this.limitation = '',
  });
}

/// Kết quả sau khi parse file Excel khảo sát
class SurveyImportResult {
  final List<SurveyRow> rows;
  final String? error;

  const SurveyImportResult({required this.rows, this.error});
}

/// Dịch vụ đọc file Excel khảo sát sinh viên (xuất từ Google Forms) hoặc File nhận xét giảng viên
class SurveyImportService {
  // Các bộ từ khóa nhận diện cột
  static const _rollKeys = {'roll', 'roll_number', 'mssv', 'ma sv', 'ma sinh vien', 'roll number'};
  static const _nameKeys = {'fullname', 'full name', 'name', 'ho ten', 'ten sinh vien', 'ho va ten'};
  static const _emailKeys = {'email', 'e-mail', 'email address', 'dia chi email'};
  static const _groupKeys = {'group_code', 'group code', 'groupcode', 'ma nhom', 'nhom'};
  static const _topicKeys = {'topic_code', 'topic code', 'topiccode', 'ma de tai', 'de tai'};

  SurveyImportResult parseBytes(List<int> bytes) {
    try {
      final excel = Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) {
        return const SurveyImportResult(rows: [], error: 'File không có sheet nào.');
      }

      final sheet = excel.tables.values.first;
      if (sheet.rows.isEmpty) {
        return const SurveyImportResult(rows: [], error: 'Sheet trống.');
      }

      final rawRows = sheet.rows;

      // Tìm dòng header (có cột Roll hoặc cột Group)
      int? headerIdx;
      for (var i = 0; i < rawRows.length; i++) {
        final rollCol = _findColumn(rawRows[i], _rollKeys);
        final groupCol = _findColumn(rawRows[i], _groupKeys);
        
        // Dòng tiêu đề phải có MSSV hoặc Mã Nhóm
        if (rollCol != null || groupCol != null) {
          headerIdx = i;
          break;
        }
      }

      if (headerIdx == null) {
        return const SurveyImportResult(
          rows: [],
          error: 'Không tìm thấy dòng tiêu đề hợp lệ.\n'
              'Đảm bảo file Excel có chứa cột "Mã nhóm" hoặc "MSSV / Roll".',
        );
      }

      final headerRow = rawRows[headerIdx];

      // Lấy vị trí từng cột
      final colRoll = _findColumn(headerRow, _rollKeys);
      final colName = _findColumn(headerRow, _nameKeys);
      final colEmail = _findColumn(headerRow, _emailKeys);
      final colGroup = _findColumn(headerRow, _groupKeys);
      final colTopic = _findColumn(headerRow, _topicKeys);
      final colTitleVn = _findColumnContains(headerRow, ['1.1', 'viet', 'vn', 'vietnamese']);
      final colTitleEn = _findColumnContains(headerRow, ['1.2', 'english', 'en', 'anh']);
      final colEval = _findColumnContains(headerRow, ['student evaluation', 'nhan xet cua sinh vien']);
      
      // Teacher evaluation columns
      final colContent = _findColumnContains(headerRow, ['3.1', 'noi dung khoa luan', 'noi dung']);
      final colForm = _findColumnContains(headerRow, ['3.2', 'hinh thuc thao luan', 'hinh thuc']);
      final colAttitude = _findColumnContains(headerRow, ['3.3', 'thai do cua sinh vien', 'thai do']);
      // 4.1 Đạt ở mức nào hoặc Nhận xét
      final colAchievement = _findColumnContains(headerRow, ['4.1', 'dat o muc nao', 'nhan xet']);
      final colLimitation = _findColumnContains(headerRow, ['4.2', 'han che']);

      final result = <SurveyRow>[];

      for (var r = headerIdx + 1; r < rawRows.length; r++) {
        final row = rawRows[r];
        final roll = _cell(row, colRoll);
        final name = _cell(row, colName);
        final group = _cell(row, colGroup);
        final topic = _cell(row, colTopic);

        // Bỏ qua dòng trống định danh hoàn toàn
        if (roll.isEmpty && name.isEmpty && group.isEmpty && topic.isEmpty) continue;

        result.add(SurveyRow(
          roll: roll.toUpperCase(),
          fullname: name,
          email: _cell(row, colEmail),
          groupCode: group,
          topicCode: topic,
          titleVn: _cell(row, colTitleVn),
          titleEn: _cell(row, colTitleEn),
          studentEval: _cell(row, colEval),
          content: _cell(row, colContent),
          form: _cell(row, colForm),
          attitude: _cell(row, colAttitude),
          achievement: _cell(row, colAchievement),
          limitation: _cell(row, colLimitation),
        ));
      }

      if (result.isEmpty) {
        return const SurveyImportResult(
          rows: [],
          error: 'Không có dòng dữ liệu hợp lệ sau tiêu đề.',
        );
      }

      return SurveyImportResult(rows: result);
    } catch (e) {
      return SurveyImportResult(rows: [], error: 'Không đọc được file Excel: $e');
    }
  }

  // Tìm chỉ số cột theo bộ từ khóa (so khớp chuẩn hóa)
  int? _findColumn(List<Data?> row, Set<String> keys) {
    for (var c = 0; c < row.length; c++) {
      final normalized = _normalize(_cell(row, c));
      if (keys.contains(normalized)) return c;
    }
    return null;
  }

  // Tìm chỉ số cột theo danh sách từ khóa con (chứa một trong các needle)
  int? _findColumnContains(List<Data?> row, List<String> needles) {
    for (var c = 0; c < row.length; c++) {
      final normalized = _normalize(_cell(row, c));
      for (final needle in needles) {
        if (normalized.contains(needle)) return c;
      }
    }
    return null;
  }

  // Đọc giá trị ô tại vị trí cột (an toàn, trả về rỗng nếu null/ngoài biên)
  String _cell(List<Data?> row, int? col) {
    if (col == null || col < 0 || col >= row.length) return '';
    final v = row[col]?.value;
    if (v == null) return '';
    return switch (v) {
      TextCellValue(:final value) => _flattenSpan(value).trim(),
      IntCellValue(:final value) => value.toString(),
      DoubleCellValue(:final value) => value.toString(),
      BoolCellValue(:final value) => value ? 'true' : 'false',
      FormulaCellValue(:final formula) => formula.trim(),
      _ => '',
    };
  }

  // Làm phẳng TextSpan
  String _flattenSpan(TextSpan span) {
    final b = StringBuffer();
    if (span.text != null) b.write(span.text);
    for (final child in span.children ?? []) {
      b.write(_flattenSpan(child));
    }
    return b.toString();
  }

  // Chuẩn hóa chuỗi (loại dấu, chữ thường, gộp khoảng trắng)
  String _normalize(String s) {
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
    for (final ch in s.toLowerCase().runes) {
      final c = String.fromCharCode(ch);
      buf.write(map[c] ?? c);
    }
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
