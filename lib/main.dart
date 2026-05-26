import 'package:flutter/material.dart';

import 'screens/thesis_workbench_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExcelCmtApp());
}

class ExcelCmtApp extends StatelessWidget {
  const ExcelCmtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FuGrade CMT Tool',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const ThesisWorkbenchScreen(),
    );
  }
}
