import 'package:flutter_test/flutter_test.dart';

import 'package:excel_cmt_tool/main.dart';

void main() {
  testWidgets('App renders title', (tester) async {
    await tester.pumpWidget(const ExcelCmtApp());
    expect(find.text('FUGE Tool — Quản lý Đánh giá Khóa luận'), findsOneWidget);
  });
}
