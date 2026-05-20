import 'write_utf8_file_io.dart'
    if (dart.library.html) 'write_utf8_file_web.dart' as impl;

Future<void> writeUtf8File(String fullPath, String content) =>
    impl.writeUtf8File(fullPath, content);
