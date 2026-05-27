import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'services/ai_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await AIService.instance.init();
  runApp(
    const ProviderScope(
      child: ExcelCmtApp(),
    ),
  );
}

class ExcelCmtApp extends StatelessWidget {
  const ExcelCmtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nhận xét đề tài',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomeScreen(),
    );
  }
}
