import 'package:excel_plus/excel_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:excel_cmt_tool/services/excel_import_service.dart';

void main() {
  final service = ExcelImportService();

  test('reads thesis group format with index column and Vietnamese headers', () {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    sheet.appendRow([
      null,
      TextCellValue('Roll'),
      TextCellValue('Name'),
      TextCellValue('Tên Khóa Luận Tiếng Việt'),
      TextCellValue('Tên Khóa Luận Tiếng Anh'),
      TextCellValue('Nội dung khóa luận/ Thesis Content'),
      TextCellValue('Hình Thức Khóa Luận'),
      TextCellValue('Thái độ của sinh viên'),
      TextCellValue('Mức độ đạt'),
      TextCellValue('Hạn chế'),
    ]);
    sheet.appendRow([
      IntCellValue(1),
      TextCellValue('SE160367'),
      TextCellValue('Lê Vũ Đình Duy'),
      TextCellValue('AB'),
      TextCellValue('BC'),
      TextCellValue('ABCCC'),
      TextCellValue('ABCCCCC'),
      TextCellValue('TỐT'),
      TextCellValue('100%'),
      TextCellValue('CÒN SAI'),
    ]);
    sheet.appendRow([
      IntCellValue(2),
      TextCellValue('SE160920'),
      TextCellValue('Lê Ngô Hiệp Quốc'),
      null,
      null,
      null,
      null,
      null,
      null,
      null,
    ]);

    final bytes = excel.encode()!;
    final res = service.decodeBytes(bytes);

    expect(res.error, isNull, reason: res.error);
    expect(res.thesis, isNotNull);
    expect(res.thesis!.students.length, 2);
    expect(res.thesis!.titleVn, 'AB');
    expect(res.thesis!.titleEn, 'BC');
    expect(res.thesis!.content, 'ABCCC');
    expect(res.thesis!.attitude, 'TỐT');
    expect(res.thesis!.students.first.roll, 'SE160367');
  });
}
