import 'package:excel_cmt_tool/models/fg_roster.dart';
import 'package:excel_cmt_tool/services/google_sheet_service.dart';
import 'package:excel_cmt_tool/services/project_merge_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses Ten VN, Ten EN, Nhan xet from sheet CSV', () {
    const csv = '''
Ma de tai,Ma nhom,Ten VN,Ten EN,Danh gia,Nhan xet SV
DT01,SP24SE080_GSP40,De tai VN,Thesis EN,Tot,Nhan xet hay
''';
    final result = GoogleSheetService().parseDelimitedText(csv);
    expect(result.error, isNull);
    expect(result.topics.length, 1);
    expect(result.topics[0].titleVn, 'De tai VN');
    expect(result.topics[0].titleEn, 'Thesis EN');
    expect(result.topics[0].nhanXetSv, 'Nhan xet hay');
    expect(result.columnSummary, contains('VN'));
  });

  test('fuzzy group code matches sheet ma nhom to fg class', () {
    const csv = '''
Ma nhom,Ten de tai tieng Viet,Ten de tai tieng Anh,Nhan xet theo goc nhin SV
GSP40,Ten VN,Ten EN,Nx
''';
    final sheet = GoogleSheetService().parseDelimitedText(csv);
    final roster = FgRoster(
      students: [
        const FgStudent(
          roll: 'SE1',
          name: 'A',
          groupCode: 'SP24SE080_GSP40',
        ),
      ],
    );
    final bundle = ProjectMergeService().merge(
      roster: roster,
      sheetTopics: sheet.topics,
    );
    expect(bundle.topics[0].students.length, 1);
    expect(bundle.topics[0].titleVn, 'Ten VN');
    expect(bundle.topics[0].maNhom, 'SP24SE080_GSP40');
  });
}
