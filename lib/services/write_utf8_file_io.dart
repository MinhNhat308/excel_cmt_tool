import 'dart:convert';
import 'dart:io';

Future<void> writeUtf8File(String fullPath, String content) async {
  final file = File(fullPath);
  await file.writeAsString(content, encoding: utf8);
}
