import 'dart:io';

import 'package:excel_plus/excel_plus.dart';
import 'package:path/path.dart' as p;

import '../models/project_model.dart';

class ExcelExportService {
  Future<List<int>> generateExcelBytes(List<ProjectModel> projects) async {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    excel.setDefaultSheet('Sheet1');

    // Header Row
    sheet.appendRow([
      TextCellValue('STT'),
      TextCellValue('Mã sinh viên'),
      TextCellValue('Họ và tên'),
      TextCellValue('Mã nhóm'),
      TextCellValue('Mã đề tài'),
      TextCellValue('Tên đề tài (Tiếng Việt)'),
      TextCellValue('Tên đề tài (Tiếng Anh)'),
      TextCellValue('Nội dung'),
      TextCellValue('Hình thức'),
      TextCellValue('Thái độ'),
      TextCellValue('Mức độ đạt'),
      TextCellValue('Hạn chế'),
      TextCellValue('Kết luận bảo vệ'),
      TextCellValue('Ghi chú'),
    ]);

    int index = 1;
    for (final project in projects) {
      for (final student in project.students) {
        final verdict = project.gvEvaluation.studentVerdicts.firstWhere(
          (v) => v.roll.toUpperCase() == student.roll.toUpperCase(),
          orElse: () => StudentVerdictModel(roll: student.roll),
        );

        String verdictText = '';
        if (verdict.agreeToDefense) verdictText = 'Đồng ý bảo vệ';
        else if (verdict.revisedForSecondDefense) verdictText = 'Sửa chữa bảo vệ lần 2';
        else if (verdict.disagreeToDefense) verdictText = 'Từ chối bảo vệ';
        else verdictText = 'Đồng ý bảo vệ'; // fallback based on UI default

        sheet.appendRow([
          TextCellValue(index.toString()),
          TextCellValue(student.roll),
          TextCellValue(student.name),
          TextCellValue(project.groupCode),
          TextCellValue(project.topicCode),
          TextCellValue(project.titleVn),
          TextCellValue(project.titleEn),
          TextCellValue(project.gvEvaluation.content),
          TextCellValue(project.gvEvaluation.form),
          TextCellValue(project.gvEvaluation.attitude),
          TextCellValue(project.gvEvaluation.achievement),
          TextCellValue(project.gvEvaluation.limitation),
          TextCellValue(verdictText),
          TextCellValue(verdict.note),
        ]);
        index++;
      }
    }

    return excel.encode()!;
  }
}
