import 'dart:convert';
import 'dart:io';

import 'package:excel_cmt_tool/services/fg_fuge_crypto_service.dart';
import 'package:excel_cmt_tool/services/fg_fuge_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decrypts FuGrade .fg and extracts SEP490 groups', () {
    const paths = [
      r'c:\Users\gioco\Downloads\phuonglhkSpring2024.fg',
      r'tools\fg_sample_decrypted.json',
    ];
    Map<String, dynamic>? root;
    for (final p in paths) {
      if (!File(p).existsSync()) continue;
      if (p.endsWith('.fg')) {
        final bytes = File(p).readAsBytesSync();
        final plain = FgFugeCryptoService().decryptFgBytes(bytes);
        root = jsonDecode(plain) as Map<String, dynamic>;
      } else {
        root = jsonDecode(File(p).readAsStringSync()) as Map<String, dynamic>;
      }
      break;
    }
    expect(root, isNotNull);

    final roster = const FgFugeParser().parseTeacherGradeJson(
      root!,
      sourcePath: 'test.fg',
    );
    expect(roster.teacher, 'phuonglhk');
    expect(roster.semester, 'Spring2024');
    expect(roster.students.length, greaterThan(0));
    expect(
      roster.students.any((s) => s.groupCode.contains('GSP')),
      isTrue,
    );
    expect(roster.groupCodes.length, greaterThanOrEqualTo(4));
  });
}
