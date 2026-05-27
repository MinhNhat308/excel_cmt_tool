import 'dart:io';
import 'package:excel_cmt_tool/models/thesis_comment.dart';
import 'package:excel_cmt_tool/services/cmt_export_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project_model.dart';
import '../services/project_provider.dart';
import 'project_detail_screen.dart';

import '../theme/app_theme.dart';

class CmtViewerScreen extends ConsumerStatefulWidget {
  const CmtViewerScreen({super.key, this.initialFilePath});

  final String? initialFilePath;

  @override
  ConsumerState<CmtViewerScreen> createState() => _CmtViewerScreenState();
}

class _CmtViewerScreenState extends ConsumerState<CmtViewerScreen> {
  final _cmtExport = CmtExportService();
  final _passwordController = TextEditingController();

  String? _filePath;
  ThesisComment? _comment;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilePath != null) {
      _filePath = widget.initialFilePath;
      // Auto-trigger password entry
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _promptPasswordAndLoad();
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickAndLoadFile() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['cmt'],
    );
    if (r == null || r.files.isEmpty) return;

    final path = r.files.single.path;
    if (path == null) return;

    setState(() {
      _filePath = path;
      _comment = null;
      _error = null;
    });

    _promptPasswordAndLoad();
  }

  Future<void> _promptPasswordAndLoad() async {
    if (_filePath == null) return;

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Giải mã tệp nhận xét (.cmt)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nhập mật khẩu mã hóa của tệp .cmt để giải mã và hiển thị thông tin.\n'
              'Nếu không có mật khẩu, hãy nhấn Tiếp tục với mật khẩu mặc định "1".',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu .cmt',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _filePath = null);
            },
            child: const Text('HỦY BỎ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _passwordController.text),
            child: const Text('TIẾP TỤC'),
          ),
        ],
      ),
    );

    if (password == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final comment = await _cmtExport.importFromFile(
        inputPath: _filePath!,
        password: password,
      );
      setState(() {
        _comment = comment;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Lỗi giải mã tệp tin .cmt: Mật khẩu không đúng hoặc tệp tin bị hỏng.\nChi tiết: $e';
        _isLoading = false;
      });
    }
  }

  void _editComment() {
    if (_comment == null) return;
    final notifier = ref.read(projectListProvider.notifier);
    
    final newProj = ProjectModel(
      topicCode: '',
      groupCode: 'CMT_EDIT', 
      titleVn: _comment!.titleVn,
      titleEn: _comment!.titleEn,
      students: _comment!.students.map((s) => StudentModel(roll: s.roll, name: s.name)).toList(),
      gvEvaluation: GvEvaluationModel(
        content: _comment!.content,
        form: _comment!.form,
        attitude: _comment!.attitude,
        achievement: _comment!.achievement,
        limitation: _comment!.limitation,
        conclusion: _comment!.conclusion,
        studentVerdicts: _comment!.students.map((s) => StudentVerdictModel(
          roll: s.roll,
          agreeToDefense: s.agreeToDefense.toLowerCase() == 'x',
          revisedForSecondDefense: s.revisedForSecondDefense.toLowerCase() == 'x',
          disagreeToDefense: s.disagreeToDefense.toLowerCase() == 'x',
          note: s.note,
        )).toList(),
      ),
    );

    notifier.addProject(newProj);
    final state = ref.read(projectListProvider);
    final newIndex = state.projects.length - 1;

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ProjectDetailScreen(projectIndex: newIndex),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trình đọc tệp tin nhận xét (.cmt)'),
      ),
      body: DecoratedBox(
        decoration: AppTheme.pageGradient(context),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // File Selector Card if no file loaded
                      if (_comment == null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.picture_as_pdf_rounded, color: scheme.primary, size: 36),
                                    const SizedBox(width: 16),
                                    Text(
                                      'Chọn tệp .cmt để giải mã và xem',
                                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Tệp .cmt là tệp nhị phân đã được mã hóa bảo mật chứa toàn bộ nhận xét đánh giá khóa luận tốt nghiệp của Hội đồng/Giảng viên.',
                                  style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  onPressed: _pickAndLoadFile,
                                  icon: const Icon(Icons.folder_open_rounded),
                                  label: const Text('CHỌN VÀ GIẢI MÃ TỆP .CMT'),
                                ),
                              ],
                            ),
                          ),
                        ),

                      if (_error != null) ...[
                        const SizedBox(height: 16),
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
                                    _error!,
                                    style: TextStyle(color: scheme.onErrorContainer),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _pickAndLoadFile,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Thử lại với mật khẩu khác'),
                        ),
                      ],

                      // Premium Presentation Card of loaded .cmt
                      if (_comment != null) ...[
                        _CmtDetailsReportCard(comment: _comment!, scheme: scheme, t: t),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('QUAY LẠI'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: _editComment,
                              icon: const Icon(Icons.edit_rounded),
                              label: const Text('CHỈNH SỬA'),
                            ),
                            FilledButton.icon(
                              onPressed: _pickAndLoadFile,
                              icon: const Icon(Icons.folder_open_rounded),
                              label: const Text('ĐỌC TỆP .CMT KHÁC'),
                            ),
                          ],
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

class _CmtDetailsReportCard extends StatelessWidget {
  const _CmtDetailsReportCard({
    required this.comment,
    required this.scheme,
    required this.t,
  });

  final ThesisComment comment;
  final ColorScheme scheme;
  final TextTheme t;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: scheme.shadow.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PHIẾU ĐÁNH GIÁ KHÓA LUẬN TỐT NGHIỆP',
                      style: t.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: scheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hệ thống đánh giá kỹ năng sinh viên (FUGE)',
                      style: t.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    comment.semester.isNotEmpty ? comment.semester : 'FA25',
                    style: t.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: scheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Metadata Grid
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 4,
              children: [
                _InfoBlock(title: 'Giảng viên đánh giá', value: comment.teacher, t: t, scheme: scheme),
                _InfoBlock(title: 'Môn học', value: comment.subjectCode.isNotEmpty ? comment.subjectCode : 'SEP490', t: t, scheme: scheme),
                _InfoBlock(title: 'Lớp học', value: comment.className.isNotEmpty ? comment.className : 'N/A', t: t, scheme: scheme),
              ],
            ),
            const SizedBox(height: 24),

            // Thesis Title
            _InfoSection(
              title: 'TÊN ĐỀ TÀI KHÓA LUẬN',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tiếng Việt:', style: t.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: scheme.primary)),
                  Text(comment.titleVn, style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('Tiếng Anh:', style: t.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: scheme.primary)),
                  Text(comment.titleEn, style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              scheme: scheme,
              t: t,
            ),
            const SizedBox(height: 24),

            // Detailed Comments
            _InfoSection(
              title: 'Ý KIẾN ĐÁNH GIÁ CỦA GIẢNG VIÊN',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CmtBlock(label: '1. Nội dung khóa luận', text: comment.content, t: t, scheme: scheme),
                  const SizedBox(height: 16),
                  _CmtBlock(label: '2. Hình thức trình bày', text: comment.form, t: t, scheme: scheme),
                  const SizedBox(height: 16),
                  _CmtBlock(label: '3. Thái độ làm việc', text: comment.attitude, t: t, scheme: scheme),
                  const SizedBox(height: 16),
                  _CmtBlock(label: '4. Kết quả đạt được', text: comment.achievement, t: t, scheme: scheme),
                  const SizedBox(height: 16),
                  _CmtBlock(label: '5. Hạn chế', text: comment.limitation, t: t, scheme: scheme),
                ],
              ),
              scheme: scheme,
              t: t,
            ),
            const SizedBox(height: 24),

            // Student list and verdicts
            _InfoSection(
              title: 'KẾT LUẬN BẢO VỆ CHO TỪNG SINH VIÊN',
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.5),
                  1: FixedColumnWidth(100),
                  2: FixedColumnWidth(100),
                  3: FixedColumnWidth(100),
                  4: FlexColumnWidth(3),
                },
                border: TableBorder.all(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(4)),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: scheme.surfaceContainer),
                    children: const [
                      Padding(padding: EdgeInsets.all(12), child: Text('Sinh viên', style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: EdgeInsets.all(12), child: Text('Đồng ý BV', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: EdgeInsets.all(12), child: Text('Sửa lại BV2', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: EdgeInsets.all(12), child: Text('Từ chối BV', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: EdgeInsets.all(12), child: Text('Ghi chú', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  ...comment.students.map((s) {
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text('${s.roll}\n${s.name}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                        // Agree to defense checkbox indicator
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            s.agreeToDefense == 'x' ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                            color: s.agreeToDefense == 'x' ? Colors.green : scheme.outline,
                          ),
                        ),
                        // Revised checkbox indicator
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            s.revisedForSecondDefense == 'x' ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                            color: s.revisedForSecondDefense == 'x' ? Colors.orange : scheme.outline,
                          ),
                        ),
                        // Disagree checkbox indicator
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            s.disagreeToDefense == 'x' ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                            color: s.disagreeToDefense == 'x' ? Colors.red : scheme.outline,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(s.note.isNotEmpty ? s.note : '—', style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              scheme: scheme,
              t: t,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.title,
    required this.value,
    required this.t,
    required this.scheme,
  });

  final String title;
  final String value;
  final TextTheme t;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value.isNotEmpty ? value : 'N/A', style: t.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.title,
    required this.child,
    required this.scheme,
    required this.t,
  });

  final String title;
  final Widget child;
  final ColorScheme scheme;
  final TextTheme t;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: t.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: scheme.primary,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _CmtBlock extends StatelessWidget {
  const _CmtBlock({
    required this.label,
    required this.text,
    required this.t,
    required this.scheme,
  });

  final String label;
  final String text;
  final TextTheme t;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: scheme.secondary)),
        const SizedBox(height: 4),
        Text(
          text.isNotEmpty ? text : '(Chưa điền thông tin)',
          style: t.bodyMedium?.copyWith(
            fontStyle: text.isEmpty ? FontStyle.italic : null,
            color: text.isNotEmpty ? scheme.onSurface : scheme.outline,
          ),
        ),
      ],
    );
  }
}
