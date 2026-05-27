import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../models/project_model.dart';
import '../services/project_provider.dart';

class ProjectTableEditor extends ConsumerStatefulWidget {
  const ProjectTableEditor({super.key});

  @override
  ConsumerState<ProjectTableEditor> createState() => _ProjectTableEditorState();
}

class _ProjectTableEditorState extends ConsumerState<ProjectTableEditor> {
  final _teacherController = TextEditingController();
  final _semesterController = TextEditingController();
  final _subjectController = TextEditingController();
  final _classController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(projectListProvider);
      _teacherController.text = state.teacher;
      _semesterController.text = state.semester;
      _subjectController.text = state.subjectCode;
      _classController.text = state.className;
    });
  }

  @override
  void dispose() {
    _teacherController.dispose();
    _semesterController.dispose();
    _subjectController.dispose();
    _classController.dispose();
    super.dispose();
  }

  void _saveMetadata() {
    ref.read(projectListProvider.notifier).updateMetadata(
          teacher: _teacherController.text.trim(),
          semester: _semesterController.text.trim(),
          subjectCode: _subjectController.text.trim(),
          className: _classController.text.trim(),
        );
  }

  Future<void> _saveFile() async {
    _saveMetadata();
    final notifier = ref.read(projectListProvider.notifier);
    final state = ref.read(projectListProvider);

    if (state.filePath.isNotEmpty) {
      final success = await notifier.saveToCurrentFile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Đã lưu file thành công!' : 'Có lỗi khi lưu file.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    } else {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Lưu file cấu hình .fg',
        fileName: 'danh_sach_de_tai.fg',
        type: FileType.custom,
        allowedExtensions: const ['fg'],
      );
      if (path == null) return;
      final fullPath = path.toLowerCase().endsWith('.fg') ? path : '$path.fg';
      final success = await notifier.saveToNewFile(fullPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Đã tạo và lưu file .fg thành công!' : 'Có lỗi khi lưu file.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _addNewProject() {
    final newProj = ProjectModel(
      topicCode: (ref.read(projectListProvider).projects.length + 1).toString().padLeft(2, '0'),
      groupCode: 'GR${(ref.read(projectListProvider).projects.length + 1).toString().padLeft(3, '0')}',
      titleVn: 'Đề tài tiếng Việt mới',
      titleEn: 'New English Topic Title',
      students: const [
        StudentModel(roll: 'SE000000', name: 'Sinh viên mới A'),
      ],
    );
    ref.read(projectListProvider.notifier).addProject(newProj);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectListProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng chỉnh sửa danh sách đề tài (.fg)'),
        actions: [
          IconButton(
            tooltip: 'Thêm nhóm đề tài mới',
            icon: const Icon(Icons.add_box_rounded),
            onPressed: _addNewProject,
          ),
          IconButton(
            tooltip: 'Lưu tệp .fg',
            icon: const Icon(Icons.save_rounded),
            onPressed: _saveFile,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.surfaceContainerLowest,
              scheme.surfaceContainerHigh.withOpacity(0.4),
            ],
          ),
        ),
        child: Column(
          children: [
            // Panel thông tin chung (Metadata Editor)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thông tin lớp học & giảng viên',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _teacherController,
                              decoration: const InputDecoration(
                                labelText: 'Giảng viên hướng dẫn',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              onChanged: (_) => _saveMetadata(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _semesterController,
                              decoration: const InputDecoration(
                                labelText: 'Học kỳ',
                                prefixIcon: Icon(Icons.calendar_today_rounded),
                              ),
                              onChanged: (_) => _saveMetadata(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _subjectController,
                              decoration: const InputDecoration(
                                labelText: 'Mã môn',
                                prefixIcon: Icon(Icons.subtitles_rounded),
                              ),
                              onChanged: (_) => _saveMetadata(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Danh sách các đề tài dạng bảng
            Expanded(
              child: state.projects.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.layers_clear_rounded, size: 64, color: scheme.outline),
                          const SizedBox(height: 12),
                          Text(
                            'Chưa có danh sách đề tài nào.',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _addNewProject,
                            icon: const Icon(Icons.add),
                            label: const Text('Tạo nhóm đề tài đầu tiên'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: state.projects.length,
                      itemBuilder: (context, projectIndex) {
                        final project = state.projects[projectIndex];
                        return _ProjectTableBlock(
                          project: project,
                          projectIndex: projectIndex,
                          scheme: scheme,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectTableBlock extends ConsumerWidget {
  const _ProjectTableBlock({
    required this.project,
    required this.projectIndex,
    required this.scheme,
  });

  final ProjectModel project;
  final int projectIndex;
  final ColorScheme scheme;

  Color _getStatusColor(String status) {
    switch (status) {
      case 'VALID':
        return Colors.green;
      case 'DUPLICATE':
        return Colors.orange;
      case 'TOPIC_CONFLICT':
        return Colors.purple;
      case 'MISSING_DATA':
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final notifier = ref.read(projectListProvider.notifier);

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: _getStatusColor(project.validationStatus).withOpacity(0.5),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header nhóm đề tài
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  'Mã đề tài: ',
                                  style: t.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                                Expanded(
                                  child: SizedBox(
                                    height: 32,
                                    child: TextField(
                                      controller: TextEditingController(text: project.topicCode)
                                        ..selection = TextSelection.collapsed(offset: project.topicCode.length),
                                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                                        border: UnderlineInputBorder(),
                                      ),
                                      onChanged: (val) {
                                        notifier.updateProjectField(projectIndex, topicCode: val.trim());
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  'Nhóm: ',
                                  style: t.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                                Expanded(
                                  child: SizedBox(
                                    height: 32,
                                    child: TextField(
                                      controller: TextEditingController(text: project.groupCode)
                                        ..selection = TextSelection.collapsed(offset: project.groupCode.length),
                                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                                        border: UnderlineInputBorder(),
                                      ),
                                      onChanged: (val) {
                                        notifier.updateProjectField(projectIndex, groupCode: val.trim());
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(project.validationStatus).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              project.validationStatus,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(project.validationStatus),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Xóa nhóm đề tài này',
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Xác nhận xóa'),
                        content: Text('Bạn có chắc chắn muốn xóa nhóm đề tài ${project.groupCode}?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Hủy'),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            onPressed: () {
                              notifier.removeProject(projectIndex);
                              Navigator.pop(ctx);
                            },
                            child: const Text('Xóa'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Chỉnh sửa tên đề tài
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: project.titleVn)
                      ..selection = TextSelection.collapsed(offset: project.titleVn.length),
                    decoration: const InputDecoration(
                      labelText: 'Tên đề tài (Tiếng Việt)',
                      isDense: true,
                    ),
                    onChanged: (val) {
                      notifier.updateProjectField(projectIndex, titleVn: val.trim());
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: project.titleEn)
                      ..selection = TextSelection.collapsed(offset: project.titleEn.length),
                    decoration: const InputDecoration(
                      labelText: 'Tên đề tài (Tiếng Anh)',
                      isDense: true,
                    ),
                    onChanged: (val) {
                      notifier.updateProjectField(projectIndex, titleEn: val.trim());
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bảng thành viên nhóm (Students Spreadsheet)
            Text(
              'Danh sách sinh viên thực tế',
              style: t.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
                color: scheme.surfaceContainerLow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1.2), // Roll
                    1: FlexColumnWidth(2.5), // Name
                    2: FlexColumnWidth(2.5), // Email
                    3: FixedColumnWidth(60), // Actions
                  },
                  border: TableBorder.symmetric(
                    inside: BorderSide(color: scheme.outlineVariant),
                  ),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    // Header của Table
                    TableRow(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                      ),
                      children: [
                        _buildTableHeaderCell('MSSV (Roll)', t, scheme),
                        _buildTableHeaderCell('Họ & Tên', t, scheme),
                        _buildTableHeaderCell('Kết luận bảo vệ', t, scheme),
                        const SizedBox.shrink(),
                      ],
                    ),
                    // Danh sách sinh viên
                    ...List.generate(project.students.length, (studentIndex) {
                      final student = project.students[studentIndex];
                      return TableRow(
                        children: [
                          _buildEditableTableCell(
                            text: student.roll,
                            hint: 'MSSV...',
                            onChanged: (val) {
                              notifier.updateStudentInProject(
                                projectIndex,
                                studentIndex,
                                student.copyWith(roll: val.trim().toUpperCase()),
                              );
                            },
                          ),
                          _buildEditableTableCell(
                            text: student.name,
                            hint: 'Họ và tên...',
                            onChanged: (val) {
                              notifier.updateStudentInProject(
                                projectIndex,
                                studentIndex,
                                student.copyWith(name: val.trim()),
                              );
                            },
                          ),
                          _buildVerdictDropdownCell(
                            verdict: project.gvEvaluation.studentVerdicts.firstWhere(
                              (v) => v.roll == student.roll,
                              orElse: () => StudentVerdictModel(roll: student.roll),
                            ),
                            onChanged: (val) {
                              final verdicts = List<StudentVerdictModel>.from(project.gvEvaluation.studentVerdicts);
                              final idx = verdicts.indexWhere((v) => v.roll == student.roll);
                              final newVerdict = StudentVerdictModel(
                                roll: student.roll,
                                agreeToDefense: val == 0,
                                revisedForSecondDefense: val == 1,
                                disagreeToDefense: val == 2,
                                note: idx >= 0 ? verdicts[idx].note : '',
                              );
                              if (idx >= 0) {
                                verdicts[idx] = newVerdict;
                              } else {
                                verdicts.add(newVerdict);
                              }

                              notifier.updateProject(
                                projectIndex,
                                project.copyWith(
                                  gvEvaluation: project.gvEvaluation.copyWith(studentVerdicts: verdicts),
                                ),
                              );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: IconButton(
                              icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 20),
                              tooltip: 'Xóa sinh viên',
                              onPressed: () {
                                notifier.removeStudentFromProject(projectIndex, studentIndex);
                              },
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  notifier.addStudentToProject(
                    projectIndex,
                    StudentModel(
                      roll: 'SE${(project.students.length + 100000).toString()}',
                      name: 'Sinh viên mới',
                      email: '',
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Thêm sinh viên vào nhóm'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String text, TextTheme t, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Text(
        text,
        style: t.bodySmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: scheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildEditableTableCell({
    required String text,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      child: TextField(
        controller: TextEditingController(text: text)
          ..selection = TextSelection.collapsed(offset: text.length),
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildVerdictDropdownCell({
    required StudentVerdictModel verdict,
    required ValueChanged<int?> onChanged,
  }) {
    int currentValue = 0; // Default to 'Đồng ý bảo vệ'
    if (verdict.revisedForSecondDefense) currentValue = 1;
    else if (verdict.disagreeToDefense) currentValue = 2;
    else if (verdict.agreeToDefense) currentValue = 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      child: DropdownButtonFormField<int>(
        value: currentValue,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 6),
        ),
        isExpanded: true,
        style: const TextStyle(fontSize: 13, color: Colors.black),
        items: const [
          DropdownMenuItem(value: -1, child: Text('Chưa đánh giá', overflow: TextOverflow.ellipsis)),
          DropdownMenuItem(value: 0, child: Text('Đồng ý bảo vệ', overflow: TextOverflow.ellipsis)),
          DropdownMenuItem(value: 1, child: Text('Sửa chữa', overflow: TextOverflow.ellipsis)),
          DropdownMenuItem(value: 2, child: Text('Không đồng ý', overflow: TextOverflow.ellipsis)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
