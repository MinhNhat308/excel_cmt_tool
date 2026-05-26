import 'dart:io';

import 'package:excel_cmt_tool/models/thesis_comment.dart';
import 'package:excel_cmt_tool/services/cmt_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = CmtExportService();

  test('round-trip .cmt export and import', () async {
    final exe = service.locateSerializer();
    if (exe == null) {
      return;
    }

    final thesis = ThesisComment(
      teacher: 'gv1',
      subjectCode: 'SEP490',
      className: 'SP24SE080_GSP40',
      semester: 'Spring2024',
      titleVn: 'De tai VN',
      titleEn: 'Thesis EN',
      content: 'Noi dung KL',
      form: 'Truc tuyen',
      attitude: 'Tot',
      achievement: 'Dat',
      limitation: 'Han che',
      students: [
        ThesisStudent(
          roll: 'SE001',
          name: 'Test SV',
          agreeToDefense: 'x',
        ),
      ],
    );

    final dir = await Directory.systemTemp.createTemp('cmt_test_');
    final cmtPath = '${dir.path}/test.cmt';
    try {
      await service.exportToFile(thesis: thesis, outputPath: cmtPath);
      final imported = await service.importFromFile(cmtPath);

      expect(imported.className, 'SP24SE080_GSP40');
      expect(imported.titleVn, 'De tai VN');
      expect(imported.content, 'Noi dung KL');
      expect(imported.form, 'Truc tuyen');
      expect(imported.attitude, 'Tot');
      expect(imported.achievement, 'Dat');
      expect(imported.limitation, 'Han che');
      expect(imported.students.length, 1);
      expect(imported.students.first.roll, 'SE001');
      expect(imported.students.first.agreeToDefense, 'x');
    } finally {
      await dir.delete(recursive: true);
    }
  }, skip: !Platform.isWindows);

  test('export does not default empty Agree_to_defense to x', () async {
    final exe = service.locateSerializer();
    if (exe == null) return;

    final thesis = ThesisComment(
      teacher: 'gv1',
      subjectCode: 'SEP490',
      className: 'GSP40',
      students: [
        ThesisStudent(roll: 'SE001', name: 'A', agreeToDefense: 'x'),
        ThesisStudent(roll: 'SE002', name: 'B', agreeToDefense: 'x'),
        ThesisStudent(roll: 'SE003', name: 'C', agreeToDefense: 'x'),
        ThesisStudent(roll: 'SE004', name: 'D'),
      ],
    );

    final dir = await Directory.systemTemp.createTemp('cmt_agree_test_');
    final cmtPath = '${dir.path}/agree.cmt';
    try {
      await service.exportToFile(thesis: thesis, outputPath: cmtPath);
      final imported = await service.importFromFile(cmtPath);
      final agreeCount = imported.students
          .where((s) => s.agreeToDefense.toLowerCase() == 'x')
          .length;
      expect(agreeCount, 3);
      expect(imported.students[3].agreeToDefense, '');
    } finally {
      await dir.delete(recursive: true);
    }
  }, skip: !Platform.isWindows);
}
