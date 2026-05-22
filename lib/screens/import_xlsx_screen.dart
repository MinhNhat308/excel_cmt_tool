import 'dart:io';
import 'package:excel_cmt_tool/models/project_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/survey_import_service.dart';
import '../services/project_provider.dart';
import '../theme/app_theme.dart';
import 'project_list_screen.dart';

class ImportXlsxScreen extends ConsumerStatefulWidget {
  const ImportXlsxScreen({super.key});

  @override
  ConsumerState<ImportXlsxScreen> createState() => _ImportXlsxScreenState();
}

class _ImportXlsxScreenState extends ConsumerState<ImportXlsxScreen> {
  final _surveyService = SurveyImportService();
  
  // Controllers
  final _teacherController = TextEditingController();
  final _semesterController = TextEditingController();
  final _subjectController = TextEditingController();
  final _classController = TextEditingController();
  final _masterKeyController = TextEditingController(text: '123456');

  String? _selectedFileName;
  List<SurveyRow> _parsedRows = [];
  String? _parseError;
  bool _isProcessing = false;
  final _previewScrollController = ScrollController();

  @override
  void dispose() {
    _teacherController.dispose();
    _semesterController.dispose();
    _subjectController.dispose();
    _classController.dispose();
    _masterKeyController.dispose();
    _previewScrollController.dispose();
    super.dispose();
  }

  Future<void> _pickAndParseExcel() async {
    setState(() {
      _isProcessing = true;
      _parseError = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isProcessing = false);
        return;
      }

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() {
          _parseError = 'Không thể đọc nội dung tệp.';
          _isProcessing = false;
        });
        return;
      }

      final importResult = _surveyService.parseBytes(bytes);
      
      setState(() {
        _selectedFileName = file.name;
        _parsedRows = importResult.rows;
        _parseError = importResult.error;
        _isProcessing = false;

        // Auto-fill some metadata if rows are present
        if (_parsedRows.isNotEmpty) {
          final first = _parsedRows.first;
          if (_subjectController.text.isEmpty) {
            _subjectController.text = first.topicCode.split('_').first;
          }
        }
      });
    } catch (e) {
      setState(() {
        _parseError = 'Lỗi phân tích cú pháp Excel: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _saveAsFg() async {
    if (_parsedRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn và phân tích tệp Excel hợp lệ trước.')),
      );
      return;
    }

    final teacher = _teacherController.text.trim();
    final semester = _semesterController.text.trim();
    final subjectCode = _subjectController.text.trim();
    final className = _classController.text.trim();
    final masterKey = _masterKeyController.text;

    if (teacher.isEmpty || semester.isEmpty || subjectCode.isEmpty || className.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ các trường thông tin chung.')),
      );
      return;
    }

    // Group survey rows by groupCode or topicTitle to construct projects list
    final projectMap = <String, List<SurveyRow>>{};
    for (final r in _parsedRows) {
      final key = r.groupCode.isNotEmpty ? r.groupCode : (r.topicCode.isNotEmpty ? r.topicCode : 'GROUP_UNKNOWN');
      projectMap.putIfAbsent(key, () => []).add(r);
    }

    final projects = <ProjectModel>[];
    projectMap.forEach((groupCode, rows) {
      final firstRow = rows.first;
      final students = rows.map((r) {
        return StudentModel(
          roll: r.roll,
          name: r.fullname,
          email: r.email,
          studentEvaluation: r.studentEval,
        );
      }).toList();

      projects.add(
        ProjectModel(
          topicCode: firstRow.topicCode.isNotEmpty ? firstRow.topicCode : 'TOPIC_${projects.length + 1}',
          groupCode: groupCode,
          titleVn: firstRow.titleVn,
          titleEn: firstRow.titleEn,
          students: students,
          gvEvaluation: GvEvaluationModel(
            studentVerdicts: students.map((s) => StudentVerdictModel(roll: s.roll)).toList(),
          ),
        ),
      );
    });

    final defaultPathName = _selectedFileName?.replaceAll(RegExp(r'\.xlsx$', caseSensitive: false), '') ?? 'danh_sach_de_tai';
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Lưu tệp dự án (.fg)',
      fileName: '$defaultPathName.fg',
      type: FileType.custom,
      allowedExtensions: const ['fg'],
    );

    if (savePath == null) return;
    final finalPath = savePath.toLowerCase().endsWith('.fg') ? savePath : '$savePath.fg';

    setState(() => _isProcessing = true);

    ref.read(projectListProvider.notifier).setProjects(projects);
    ref.read(projectListProvider.notifier).updateMetadata(
      teacher: teacher,
      semester: semester,
      subjectCode: subjectCode,
      className: className,
    );

    // Save using the custom masterKey if entered
    final success = await ref.read(projectListProvider.notifier).saveToNewFile(finalPath, password: masterKey);
    
    setState(() => _isProcessing = false);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã lưu dự án (.fg) thành công tại:\n$finalPath')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (context) => const ProjectListScreen(),
        ),
      );
    } else {
      final err = ref.read(projectListProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lưu thất bại: ${err ?? 'Lỗi không xác định'}'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo tệp dự án (.fg) mới'),
      ),
      body: DecoratedBox(
        decoration: AppTheme.pageGradient(context),
        child: SafeArea(
          child: _isProcessing
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Step 1: Excel Selection
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bước 1: Tải lên danh sách Excel khảo sát',
                                style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Chọn tệp Excel .xlsx được xuất từ Google Forms chứa ý kiến/khảo sát sinh viên bảo vệ khóa luận.',
                                style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  FilledButton.icon(
                                    onPressed: _pickAndParseExcel,
                                    icon: const Icon(Icons.upload_file_rounded),
                                    label: const Text('Chọn tệp Excel (.xlsx)'),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      _selectedFileName != null
                                          ? 'Đã chọn: $_selectedFileName'
                                          : 'Chưa có tệp nào được chọn.',
                                      style: t.bodyMedium?.copyWith(
                                        color: _selectedFileName != null ? scheme.primary : scheme.onSurfaceVariant,
                                        fontStyle: _selectedFileName == null ? FontStyle.italic : null,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_parseError != null) ...[
                        Card(
                          color: scheme.errorContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded, color: scheme.error),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _parseError!,
                                    style: TextStyle(color: scheme.onErrorContainer),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Step 2: Input Metadata
                      if (_parsedRows.isNotEmpty) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bước 2: Thông tin chung của lớp đề tài',
                                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _teacherController,
                                        decoration: const InputDecoration(
                                          labelText: 'Tên Giảng viên (GVHD)',
                                          prefixIcon: Icon(Icons.person_outline_rounded),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextField(
                                        controller: _semesterController,
                                        decoration: const InputDecoration(
                                          labelText: 'Học kỳ (ví dụ: Fall 2025)',
                                          prefixIcon: Icon(Icons.calendar_month_outlined),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _subjectController,
                                        decoration: const InputDecoration(
                                          labelText: 'Mã môn học (ví dụ: SEP490)',
                                          prefixIcon: Icon(Icons.code_rounded),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextField(
                                        controller: _classController,
                                        decoration: const InputDecoration(
                                          labelText: 'Tên lớp (ví dụ: SE1801)',
                                          prefixIcon: Icon(Icons.class_outlined),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _masterKeyController,
                                  decoration: const InputDecoration(
                                    labelText: 'Khóa bảo mật tệp .fg (mặc định: 123456)',
                                    prefixIcon: Icon(Icons.vpn_key_outlined),
                                    helperText: 'Tệp tin .fg sẽ được mã hóa bằng khóa này để tránh chỉnh sửa trái phép.',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Preview parsed items as a primary gorgeous DataTable
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Kết quả phân tích danh sách sinh viên',
                                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: scheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'Tổng số: ${_parsedRows.length} sinh viên',
                                        style: t.bodySmall?.copyWith(
                                          color: scheme.onPrimaryContainer,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: scheme.outlineVariant),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    height: 400,
                                    width: double.infinity,
                                    child: Scrollbar(
                                      controller: _previewScrollController,
                                      thumbVisibility: true,
                                      trackVisibility: true,
                                      child: SingleChildScrollView(
                                        controller: _previewScrollController,
                                        scrollDirection: Axis.vertical,
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Theme(
                                            data: Theme.of(context).copyWith(
                                              dividerColor: scheme.outlineVariant,
                                            ),
                                            child: DataTable(
                                              headingRowColor: MaterialStateProperty.all(scheme.surfaceVariant.withOpacity(0.5)),
                                              dataRowMinHeight: 48,
                                              dataRowMaxHeight: 60,
                                              columns: const [
                                                DataColumn(label: Text('STT', style: TextStyle(fontWeight: FontWeight.bold))),
                                                DataColumn(label: Text('MSSV', style: TextStyle(fontWeight: FontWeight.bold))),
                                                DataColumn(label: Text('Họ và Tên', style: TextStyle(fontWeight: FontWeight.bold))),
                                                DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                                                DataColumn(label: Text('Nhóm', style: TextStyle(fontWeight: FontWeight.bold))),
                                                DataColumn(label: Text('Mã Đề Tài', style: TextStyle(fontWeight: FontWeight.bold))),
                                                DataColumn(label: Text('Tên Đề Tài (VN)', style: TextStyle(fontWeight: FontWeight.bold))),
                                                DataColumn(label: Text('Tên Đề Tài (EN)', style: TextStyle(fontWeight: FontWeight.bold))),
                                              ],
                                              rows: List.generate(_parsedRows.length, (index) {
                                                final r = _parsedRows[index];
                                                final isEven = index % 2 == 0;
                                                return DataRow(
                                                  color: MaterialStateProperty.all(
                                                    isEven ? Colors.transparent : scheme.surfaceVariant.withOpacity(0.1),
                                                  ),
                                                  cells: [
                                                    DataCell(Text('${index + 1}')),
                                                    DataCell(Text(r.roll, style: const TextStyle(fontWeight: FontWeight.w600))),
                                                    DataCell(Text(r.fullname)),
                                                    DataCell(Text(r.email)),
                                                    DataCell(
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: scheme.secondaryContainer,
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          r.groupCode,
                                                          style: TextStyle(color: scheme.onSecondaryContainer, fontSize: 12),
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(Text(r.topicCode)),
                                                    DataCell(
                                                      SizedBox(
                                                        width: 250,
                                                        child: Text(
                                                          r.titleVn,
                                                          overflow: TextOverflow.ellipsis,
                                                          maxLines: 2,
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      SizedBox(
                                                        width: 250,
                                                        child: Text(
                                                          r.titleEn,
                                                          overflow: TextOverflow.ellipsis,
                                                          maxLines: 2,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              }),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        FilledButton.icon(
                          onPressed: _saveAsFg,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                          ),
                          icon: const Icon(Icons.security_rounded),
                          label: const Text('LƯU VÀ TẠO TỆP DỰ ÁN (.fg) AN TOÀN'),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
