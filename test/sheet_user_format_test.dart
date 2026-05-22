import 'package:excel_cmt_tool/services/google_sheet_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses user sheet format with tabs and Vietnamese headers', () {
    const tsv = '''
MÃ ĐỀ TÀI\tMÃ NHÓM\tTẾN ĐỀ TÀI TIẾNG VIỆT\tTÊN ĐỀ TÀI TIẾNG ANH\tĐÁNH GIÁ\tNHẬN XÉT
FPT01\tSP24SE081_GSP43\tĐỀ TÀI 1\tĐỀ TÀI 1\tTỐT 1\tNHẬN XÉT 1
FPT02\tSP24SE080_GSP40\tĐỀ TÀI 2\tĐỀ TÀI 2\tTỐT 2\tNHẬN XÉT 2
''';
    final result = GoogleSheetService().parseDelimitedText(tsv);
    expect(result.error, isNull);
    expect(result.topics.length, 2);
    expect(result.topics[0].maDeTai, 'FPT01');
    expect(result.topics[0].maNhom, 'SP24SE081_GSP43');
    expect(result.topics[0].titleVn, 'ĐỀ TÀI 1');
    expect(result.topics[0].titleEn, 'ĐỀ TÀI 1');
    expect(result.topics[0].danhGia, 'TỐT 1');
    expect(result.topics[0].nhanXetSv, 'NHẬN XÉT 1');
  });
}
