import 'package:excel_cmt_tool/utils/fugrade_password.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forCmtExport hashes plain text', () {
    expect(
      FugradePassword.forCmtExport('secret'),
      '5ebe2294ecd0e0f08eab7690d2a6ee69',
    );
  });

  test('forCmtExport keeps existing MD5', () {
    const hash = 'c4ca4238a0b923820dcc509a6f75849b';
    expect(FugradePassword.forCmtExport(hash), hash);
  });

  test('forCmtExport default when empty', () {
    expect(
      FugradePassword.forCmtExport(''),
      'c4ca4238a0b923820dcc509a6f75849b',
    );
  });

  test('looksLikeMd5', () {
    expect(FugradePassword.looksLikeMd5('c4ca4238a0b923820dcc509a6f75849b'), isTrue);
    expect(FugradePassword.looksLikeMd5('plain'), isFalse);
  });
}
