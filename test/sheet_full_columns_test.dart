import 'package:excel_cmt_tool/services/google_sheet_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses full thesis sheet columns from user template', () {
    const tsv = '''
MÃ ĐỀ TÀI\tMÃ NHÓM\tTẾN ĐỀ TÀI TIẾNG VIỆT\tTÊN ĐỀ TÀI TIẾNG ANH\tNỘI DUNG KHÓA LUẬN\tHÌNH THỨC KHÓA LUẬN\tTHÁI ĐỘ CỦA SINH VIÊN\tMỨC ĐỘ ĐẠT ĐƯỢC SO VỚI MỤC TIÊU\tHẠN CHẾ
FPT01\tSP24SE081_GSP43\tĐỀ TÀI 1\tTHESIS 1\tABCCC\tTRỰC TUYẾN\tTỐT\tTỐT 1\tCÒN NHIỀU HẠN CHẾ
''';
    final result = GoogleSheetService().parseDelimitedText(tsv);
    expect(result.error, isNull);
    expect(result.topics.length, 1);
    final t = result.topics.first;
    expect(t.maDeTai, 'FPT01');
    expect(t.maNhom, 'SP24SE081_GSP43');
    expect(t.titleVn, 'ĐỀ TÀI 1');
    expect(t.titleEn, 'THESIS 1');
    expect(t.content, 'ABCCC');
    expect(t.form, 'TRỰC TUYẾN');
    expect(t.attitude, 'TỐT');
    expect(t.achievement, 'TỐT 1');
    expect(t.limitation, 'CÒN NHIỀU HẠN CHẾ');
  });
}
