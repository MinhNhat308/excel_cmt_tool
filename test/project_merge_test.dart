import 'package:excel_cmt_tool/models/de_tai_record.dart';
import 'package:excel_cmt_tool/models/fg_roster.dart';
import 'package:excel_cmt_tool/services/project_merge_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('merge attaches students by group code', () {
    final roster = FgRoster(
      students: [
        const FgStudent(roll: 'SE001', name: 'A', groupCode: 'G01'),
        const FgStudent(roll: 'SE002', name: 'B', groupCode: 'G01'),
        const FgStudent(roll: 'SE003', name: 'C', groupCode: 'G02'),
      ],
    );
    final topics = [
      DeTaiRecord(maDeTai: 'DT1', maNhom: 'g01', titleVn: 'Đề 1'),
      DeTaiRecord(maDeTai: 'DT2', maNhom: 'G02', titleVn: 'Đề 2'),
      DeTaiRecord(maDeTai: 'DT3', maNhom: 'X99', titleVn: 'Đề 3'),
    ];
    final bundle = ProjectMergeService().merge(roster: roster, sheetTopics: topics);
    expect(bundle.topics[0].students.length, 2);
    expect(bundle.topics[1].students.length, 1);
    expect(bundle.topics[2].students.length, 0);
  });

  test('partial group code GSP40 matches full fg class', () {
    final roster = FgRoster(
      students: [
        const FgStudent(
          roll: 'SE1',
          name: 'A',
          groupCode: 'SP24SE080_GSP40',
        ),
      ],
    );
    final topics = [
      DeTaiRecord(maNhom: 'GSP40', titleVn: 'Đề 1', nhanXetSv: 'OK'),
    ];
    final bundle = ProjectMergeService().merge(roster: roster, sheetTopics: topics);
    expect(bundle.topics[0].students.length, 1);
    expect(bundle.topics[0].titleVn, 'Đề 1');
    expect(bundle.topics[0].nhanXetSv, 'OK');
    expect(bundle.topics[0].maNhom, 'SP24SE080_GSP40');
  });
}
