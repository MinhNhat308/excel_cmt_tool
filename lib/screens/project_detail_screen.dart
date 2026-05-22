import 'dart:io';
import 'package:excel_cmt_tool/models/project_model.dart';
import 'package:excel_cmt_tool/models/thesis_comment.dart';
import 'package:excel_cmt_tool/services/cmt_export_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/project_provider.dart';
import '../theme/app_theme.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectIndex});

  final int projectIndex;

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  final _cmtExport = CmtExportService();

  // Teacher Form Controllers
  final _contentController = TextEditingController();
  final _formController = TextEditingController();
  final _attitudeController = TextEditingController();
  final _achievementController = TextEditingController();
  final _limitationController = TextEditingController();

  // Verdict notes mapping: roll -> controller
  final _verdictNotes = <String, TextEditingController>{};
  
  // Track selected checkboxes (roll -> index of selected checkbox: 0 = agree, 1 = revised, 2 = disagree)
  final _verdictChoices = <String, int>{};

  // Selection state for students list (left side)
  int _selectedStudentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadProjectData();
  }

  void _loadProjectData() {
    final state = ref.read(projectListProvider);
    if (widget.projectIndex < 0 || widget.projectIndex >= state.projects.length) return;
    
    final project = state.projects[widget.projectIndex];
    final eval = project.gvEvaluation;

    _contentController.text = eval.content;
    _formController.text = eval.form;
    _attitudeController.text = eval.attitude;
    _achievementController.text = eval.achievement;
    _limitationController.text = eval.limitation;

    // Load student verdicts
    for (final s in project.students) {
      final v = eval.studentVerdicts.firstWhere(
        (x) => x.roll.toUpperCase() == s.roll.toUpperCase(),
        orElse: () => StudentVerdictModel(roll: s.roll),
      );
      
      _verdictNotes[s.roll] = TextEditingController(text: v.note);
      
      if (v.agreeToDefense) {
        _verdictChoices[s.roll] = 0;
      } else if (v.revisedForSecondDefense) {
        _verdictChoices[s.roll] = 1;
      } else if (v.disagreeToDefense) {
        _verdictChoices[s.roll] = 2;
      } else {
        _verdictChoices[s.roll] = 0; // Default to agree to defense
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _formController.dispose();
    _attitudeController.dispose();
    _achievementController.dispose();
    _limitationController.dispose();
    for (final c in _verdictNotes.values) {
      c.dispose();
    }
    super.dispose();
  }

  // Save evaluations back to current .fg project
  void _saveEvaluation() {
    final state = ref.read(projectListProvider);
    final project = state.projects[widget.projectIndex];

    final verdicts = project.students.map((s) {
      final choice = _verdictChoices[s.roll] ?? 0;
      return StudentVerdictModel(
        roll: s.roll,
        agreeToDefense: choice == 0,
        revisedForSecondDefense: choice == 1,
        disagreeToDefense: choice == 2,
        note: _verdictNotes[s.roll]?.text.trim() ?? '',
      );
    }).toList();

    final updatedEval = GvEvaluationModel(
      content: _contentController.text.trim(),
      form: _formController.text.trim(),
      attitude: _attitudeController.text.trim(),
      achievement: _achievementController.text.trim(),
      limitation: _limitationController.text.trim(),
      studentVerdicts: verdicts,
    );

    ref.read(projectListProvider.notifier).updateProject(
      widget.projectIndex,
      project.copyWith(gvEvaluation: updatedEval),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu thông tin đánh giá của Giảng viên!')),
    );
  }

  // Export single .cmt
  Future<void> _exportCmt() async {
    final state = ref.read(projectListProvider);
    final project = state.projects[widget.projectIndex];

    // Auto-save form contents first
    _saveEvaluation();

    final password = await _showPasswordPrompt();
    if (password == null) return;

    final name = '${project.groupCode}_${project.topicCode}';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Xuất file nhận xét nhóm (.cmt)',
      fileName: '$name.cmt',
      type: FileType.custom,
      allowedExtensions: const ['cmt'],
    );

    if (path == null) return;
    final fullPath = path.toLowerCase().endsWith('.cmt') ? path : '$path.cmt';

    try {
      final List<ThesisStudent> tstudents = [];
      for (final s in project.students) {
        final choice = _verdictChoices[s.roll] ?? 0;
        tstudents.add(ThesisStudent(
          roll: s.roll,
          name: s.name,
          agreeToDefense: choice == 0 ? 'x' : '',
          revisedForSecondDefense: choice == 1 ? 'x' : '',
          disagreeToDefense: choice == 2 ? 'x' : '',
          note: _verdictNotes[s.roll]?.text.trim() ?? '',
        ));
      }

      final thesis = ThesisComment(
        teacher: state.teacher,
        dt: project.titleVn,
        subjectCode: state.subjectCode,
        className: state.className,
        semester: state.semester,
        password: password,
        titleVn: project.titleVn,
        titleEn: project.titleEn,
        content: _contentController.text.trim(),
        form: _formController.text.trim(),
        attitude: _attitudeController.text.trim(),
        achievement: _achievementController.text.trim(),
        limitation: _limitationController.text.trim(),
        students: tstudents,
      );

      await _cmtExport.exportToFile(thesis: thesis, outputPath: fullPath);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xuất thành công file .cmt:\n$fullPath'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Lỗi xuất .cmt'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  // Import previous .cmt to pre-fill the form
  Future<void> _loadFromPreviousCmt() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['cmt'],
    );
    if (r == null || r.files.isEmpty) return;

    final path = r.files.single.path;
    if (path == null) return;

    final password = await _showPasswordPrompt();
    if (password == null) return;

    try {
      final thesis = await _cmtExport.importFromFile(inputPath: path, password: password);
      
      setState(() {
        _contentController.text = thesis.content;
        _formController.text = thesis.form;
        _attitudeController.text = thesis.attitude;
        _achievementController.text = thesis.achievement;
        _limitationController.text = thesis.limitation;

        for (final s in thesis.students) {
          _verdictNotes[s.roll]?.text = s.note;
          if (s.agreeToDefense == 'x') {
            _verdictChoices[s.roll] = 0;
          } else if (s.revisedForSecondDefense == 'x') {
            _verdictChoices[s.roll] = 1;
          } else if (s.disagreeToDefense == 'x') {
            _verdictChoices[s.roll] = 2;
          }
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tải và điền nhanh nội dung từ file .cmt cũ!')),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Lỗi tải file .cmt'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<String?> _showPasswordPrompt() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mật khẩu giải mã .cmt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nhập mật khẩu của file .cmt này.\n'
              'Nếu không nhập gì, mật khẩu mặc định là "1".',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('HỦY BỎ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('XÁC NHẬN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectListProvider);
    if (widget.projectIndex < 0 || widget.projectIndex >= state.projects.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('Không tìm thấy đề tài')),
        body: const Center(child: Text('Đề tài không tồn tại.')),
      );
    }

    final project = state.projects[widget.projectIndex];
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${project.groupCode} — ${project.topicCode}'),
        actions: [
          IconButton(
            tooltip: 'Tải nhanh nội dung từ file .cmt cũ',
            icon: const Icon(Icons.cloud_download_rounded),
            onPressed: _loadFromPreviousCmt,
          ),
          IconButton(
            tooltip: 'Lưu thay đổi đánh giá',
            icon: const Icon(Icons.check_circle_rounded),
            onPressed: _saveEvaluation,
          ),
          IconButton(
            tooltip: 'Xuất file .cmt cho nhóm này',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: _exportCmt,
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: AppTheme.pageGradient(context),
        child: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // LEFT PANEL: Students details & surveys
              Expanded(
                flex: 4,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: scheme.outlineVariant)),
                    color: scheme.surface.withOpacity(0.4),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Title Conflict Sync Banner
                        if (project.hasTitleConflict)
                          _TitleConflictSyncCard(
                            project: project,
                            projectIndex: widget.projectIndex,
                            scheme: scheme,
                            t: t,
                          ),
                        if (project.hasTitleConflict) const SizedBox(height: 16),

                        // Topic titles panel
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tên đề tài khóa luận',
                                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Tiếng Việt:',
                                  style: t.bodySmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold),
                                ),
                                Text(project.titleVn, style: t.bodyLarge),
                                const SizedBox(height: 12),
                                Text(
                                  'Tiếng Anh:',
                                  style: t.bodySmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold),
                                ),
                                Text(project.titleEn, style: t.bodyLarge),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Student List
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sinh viên trong nhóm (${project.students.length})',
                                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: project.students.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) {
                                    final s = project.students[i];
                                    final isSelected = _selectedStudentIndex == i;
                                    return ListTile(
                                      selected: isSelected,
                                      selectedTileColor: scheme.primaryContainer.withOpacity(0.4),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      title: Text('${s.roll} — ${s.name}'),
                                      subtitle: Text(s.email.isNotEmpty ? s.email : 'Chưa nhập email'),
                                      onTap: () => setState(() => _selectedStudentIndex = i),
                                      leading: CircleAvatar(
                                        backgroundColor: isSelected ? scheme.primary : scheme.surfaceContainerHighest,
                                        foregroundColor: isSelected ? scheme.onPrimary : scheme.onSurface,
                                        child: Text('${i + 1}'),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Selected Student's survey comment
                        if (project.students.isNotEmpty)
                          Card(
                            color: scheme.tertiaryContainer.withOpacity(0.3),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.feedback_outlined, color: scheme.tertiary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Tự nhận xét của sinh viên: ${project.students[_selectedStudentIndex].name}',
                                          style: t.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: scheme.onTertiaryContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    project.students[_selectedStudentIndex].studentEvaluation.isNotEmpty
                                        ? project.students[_selectedStudentIndex].studentEvaluation
                                        : 'Sinh viên chưa nộp tự nhận xét hoặc chưa import file khảo sát Google Forms.',
                                    style: t.bodyMedium?.copyWith(
                                      fontStyle: project.students[_selectedStudentIndex].studentEvaluation.isEmpty ? FontStyle.italic : null,
                                      color: scheme.onTertiaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // RIGHT PANEL: Teacher form
              Expanded(
                flex: 6,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Form đánh giá của Giảng viên',
                                style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 20),

                              TextField(
                                controller: _contentController,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  labelText: '1. Nội dung đánh giá',
                                  alignLabelWithHint: true,
                                ),
                              ),
                              const SizedBox(height: 16),

                              TextField(
                                controller: _formController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: '2. Hình thức trình bày',
                                  alignLabelWithHint: true,
                                ),
                              ),
                              const SizedBox(height: 16),

                              TextField(
                                controller: _attitudeController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: '3. Thái độ làm việc',
                                  alignLabelWithHint: true,
                                ),
                              ),
                              const SizedBox(height: 16),

                              TextField(
                                controller: _achievementController,
                                decoration: const InputDecoration(
                                  labelText: '4. Kết quả đạt được (ví dụ: Đạt mức tương đối)',
                                  prefixIcon: Icon(Icons.verified_outlined),
                                ),
                              ),
                              const SizedBox(height: 16),

                              TextField(
                                controller: _limitationController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: '5. Hạn chế',
                                  alignLabelWithHint: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Verdict Table for students
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bảng kết luận bảo vệ (Verdicts)',
                                style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              
                              Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(2.5),
                                  1: FixedColumnWidth(80),
                                  2: FixedColumnWidth(80),
                                  3: FixedColumnWidth(80),
                                  4: FlexColumnWidth(3),
                                },
                                border: TableBorder.all(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(4)),
                                children: [
                                  // Table Header
                                  TableRow(
                                    decoration: BoxDecoration(color: scheme.surfaceContainer),
                                    children: const [
                                      Padding(padding: EdgeInsets.all(12), child: Text('Sinh viên', style: TextStyle(fontWeight: FontWeight.bold))),
                                      Padding(padding: EdgeInsets.all(12), child: Text('Đồng ý', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                                      Padding(padding: EdgeInsets.all(12), child: Text('Sửa lại', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                                      Padding(padding: EdgeInsets.all(12), child: Text('Từ chối', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                                      Padding(padding: EdgeInsets.all(12), child: Text('Ghi chú', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                  ),
                                  // Table Rows for each student
                                  ...project.students.map((s) {
                                    final choice = _verdictChoices[s.roll] ?? 0;
                                    return TableRow(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Text('${s.roll}\n${s.name}', style: const TextStyle(fontSize: 13)),
                                        ),
                                        // Agree to defense checkbox
                                        Checkbox(
                                          value: choice == 0,
                                          onChanged: (val) {
                                            if (val == true) {
                                              setState(() => _verdictChoices[s.roll] = 0);
                                            }
                                          },
                                        ),
                                        // Revised for second defense checkbox
                                        Checkbox(
                                          value: choice == 1,
                                          onChanged: (val) {
                                            if (val == true) {
                                              setState(() => _verdictChoices[s.roll] = 1);
                                            }
                                          },
                                        ),
                                        // Disagree to defense checkbox
                                        Checkbox(
                                          value: choice == 2,
                                          onChanged: (val) {
                                            if (val == true) {
                                              setState(() => _verdictChoices[s.roll] = 2);
                                            }
                                          },
                                        ),
                                        // Note input
                                        Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: TextField(
                                            controller: _verdictNotes[s.roll],
                                            decoration: const InputDecoration(
                                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                              border: OutlineInputBorder(),
                                            ),
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('QUAY LẠI'),
                          ),
                          const SizedBox(width: 16),
                          FilledButton.icon(
                            onPressed: _saveEvaluation,
                            icon: const Icon(Icons.save_rounded),
                            label: const Text('LƯU ĐÁNH GIÁ'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleConflictSyncCard extends ConsumerWidget {
  const _TitleConflictSyncCard({
    required this.project,
    required this.projectIndex,
    required this.scheme,
    required this.t,
  });

  final ProjectModel project;
  final int projectIndex;
  final ColorScheme scheme;
  final TextTheme t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: scheme.error),
                const SizedBox(width: 8),
                Text(
                  'Xung đột tên đề tài (>10% lệch)',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: scheme.onErrorContainer),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Có sự sai lệch giữa tên đề tài gốc và tên đề tài do sinh viên khai báo trong Google Forms khảo sát:',
              style: t.bodySmall?.copyWith(color: scheme.onErrorContainer),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                project.conflictDetails,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    // Extracting the survey title from conflictDetails line if present
                    final lines = project.conflictDetails.split('\n');
                    String? newVn;
                    String? newEn;
                    for (final l in lines) {
                      if (l.contains('SV nhập: "')) {
                        final title = l.split('SV nhập: "')[1].split('"')[0];
                        if (l.contains('[VN]')) {
                          newVn = title;
                        } else if (l.contains('[EN]')) {
                          newEn = title;
                        }
                      }
                    }
                    ref.read(projectListProvider.notifier).syncTitleFromSurvey(
                          projectIndex,
                          newTitleVn: newVn,
                          newTitleEn: newEn,
                        );
                  },
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Đồng bộ tên đề tài theo khai báo sinh viên'),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
