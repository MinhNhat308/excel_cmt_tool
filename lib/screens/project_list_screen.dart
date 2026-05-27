import 'dart:io';
import 'package:archive/archive.dart';
import 'package:excel_cmt_tool/models/project_model.dart';
import 'package:excel_cmt_tool/models/thesis_comment.dart';
import 'package:excel_cmt_tool/screens/project_detail_screen.dart';
import 'package:excel_cmt_tool/screens/project_table_editor.dart';
import 'package:excel_cmt_tool/services/cmt_export_service.dart';
import 'package:excel_cmt_tool/services/survey_import_service.dart';
import 'package:excel_cmt_tool/services/excel_export_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../services/project_provider.dart';
import '../theme/app_theme.dart';

class ProjectListScreen extends ConsumerStatefulWidget {
  const ProjectListScreen({super.key});

  @override
  ConsumerState<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends ConsumerState<ProjectListScreen> {
  final _cmtExport = CmtExportService();
  final _surveyImport = SurveyImportService();

  String _searchQuery = '';
  String _statusFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectListProvider);
    final notifier = ref.read(projectListProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    // Filter projects based on query and status
    final filteredProjects = state.projects.where((p) {
      final matchesStatus = _statusFilter == 'ALL' || p.validationStatus == _statusFilter;
      final query = _searchQuery.toLowerCase().trim();
      final matchesQuery = query.isEmpty ||
          p.topicCode.toLowerCase().contains(query) ||
          p.groupCode.toLowerCase().contains(query) ||
          p.titleVn.toLowerCase().contains(query) ||
          p.titleEn.toLowerCase().contains(query) ||
          p.students.any((s) => s.roll.toLowerCase().contains(query) || s.name.toLowerCase().contains(query));
      return matchesStatus && matchesQuery;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(state.filePath.isNotEmpty
            ? 'Dự án: ${p.basename(state.filePath)}'
            : 'Hệ thống Quản lý Đề tài'),
        actions: [
          IconButton(
            tooltip: 'Xuất tệp .fg (Lưu mới)',
            icon: const Icon(Icons.save_as_rounded),
            onPressed: () async {
              final path = await FilePicker.platform.saveFile(
                dialogTitle: 'Xuất file dự án .fg',
                fileName: 'fuge_project_${DateTime.now().millisecondsSinceEpoch}.fg',
                type: FileType.custom,
                allowedExtensions: const ['fg'],
              );
              if (path == null) return;
              final finalPath = path.toLowerCase().endsWith('.fg') ? path : '$path.fg';

              final success = await notifier.saveToNewFile(finalPath);
              if (!mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã xuất thành công: ${p.basename(finalPath)}'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Xuất thất bại: ${state.error ?? "Lỗi không xác định"}'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Mở trình chỉnh sửa bảng kiểu Excel',
            icon: const Icon(Icons.grid_on_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const ProjectTableEditor(),
                ),
              );
            },
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: AppTheme.pageGradient(context),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Metadata Panel
              _MetadataHeaderPanel(state: state, scheme: scheme, t: t),
              
              // Filter and Search Bar
              _FilterSearchBar(
                searchQuery: _searchQuery,
                statusFilter: _statusFilter,
                onSearchChanged: (val) => setState(() => _searchQuery = val),
                onStatusChanged: (val) => setState(() => _statusFilter = val),
                scheme: scheme,
                t: t,
              ),

              // Responsive Projects Grid
              Expanded(
                child: filteredProjects.isEmpty
                    ? Center(
                        child: Text(
                          'Không có đề tài nào phù hợp với bộ lọc.',
                          style: t.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(24),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 380,
                          mainAxisExtent: 220,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                        ),
                        itemCount: filteredProjects.length,
                        itemBuilder: (context, index) {
                          final project = filteredProjects[index];
                          // Find original index in state.projects for updates
                          final originalIndex = state.projects.indexOf(project);
                          return _ProjectGridCard(
                            project: project,
                            originalIndex: originalIndex,
                            scheme: scheme,
                            t: t,
                          );
                        },
                      ),
              ),

              // Bottom Actions Bar
              _BottomActionsBar(
                onImportSurveys: _showImportDialog,
                onExportAllCmt: () => _exportAllCmt(state),
                onExportExcel: () => _exportToExcel(state),
                onClearEvaluations: () => _showClearEvaluationsDialog(ref),
                projectsCount: state.projects.length,
                scheme: scheme,
                t: t,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Import Dialog
  Future<void> _showImportDialog() async {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Nhập thông tin đề tài'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _importFromLocalExcel();
                },
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Chọn file Excel (.xlsx) từ máy'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('HOẶC', style: TextStyle(fontWeight: FontWeight.bold))),
              ),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'Link Google Sheet công khai',
                  hintText: 'https://docs.google.com/spreadsheets/d/...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  if (ctrl.text.trim().isNotEmpty) {
                    Navigator.pop(ctx);
                    _importFromGoogleSheet(ctrl.text.trim());
                  }
                },
                icon: const Icon(Icons.cloud_download_rounded),
                label: const Text('Tải từ Google Sheet'),
              ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('HỦY BỎ'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importFromLocalExcel() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    final bytes = r.files.single.bytes;
    if (bytes == null) return;
    _processExcelBytes(bytes);
  }

  Future<void> _importFromGoogleSheet(String link) async {
    final regex = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)');
    final match = regex.firstMatch(link);
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link Google Sheet không hợp lệ.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final sheetId = match.group(1);
    final url = 'https://docs.google.com/spreadsheets/d/$sheetId/export?format=xlsx';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final request = await HttpClient().getUrl(Uri.parse(url));
      final response = await request.close();
      final builder = BytesBuilder();
      await for (var data in response) {
        builder.add(data);
      }
      final bytes = builder.takeBytes();
      
      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200 && bytes.isNotEmpty) {
        _processExcelBytes(bytes);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tải file. Hãy đảm bảo Google Sheet đã được Bật chia sẻ "Bất kỳ ai có liên kết".'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi mạng: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _processExcelBytes(List<int> bytes) {
    final result = _surveyImport.parseBytes(bytes);
    if (result.error != null) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Lỗi phân tích Excel'),
          content: Text(result.error!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    ref.read(projectListProvider.notifier).importStudentSurveys(result.rows);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã đối sánh và cập nhật dữ liệu của ${result.rows.length} sinh viên!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Export All CMT
  Future<void> _exportAllCmt(ProjectListState state) async {
    final nonValid = state.projects.where((p) => p.validationStatus != 'VALID').toList();
    
    if (state.projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có đề tài nào để xuất.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    bool proceed = true;
    if (nonValid.isNotEmpty) {
      // Prompt user regarding non-valid projects
      proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Đề tài chưa hoàn tất'),
              content: Text(
                'Có ${nonValid.length} đề tài chưa điền đầy đủ đánh giá (trạng thái khác VALID).\n'
                'Bạn muốn bỏ qua các đề tài này hay hủy bỏ quy trình xuất?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('HỦY BỎ'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('BỎ QUA & TIẾP TỤC'),
                ),
              ],
            ),
          ) ??
          false;
    }

    if (!proceed) return;

    // Filter projects to export
    final toExport = state.projects.where((p) => p.validationStatus == 'VALID').toList();
    if (toExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có đề tài VALID nào khả dụng để xuất.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Prompt for password
    final password = await _showPasswordPrompt();
    if (password == null) return;

    // Pick save ZIP path
    final zipPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Chọn nơi lưu file .zip chứa các file .cmt',
      fileName: 'danh_sach_nhan_xet.zip',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );

    if (zipPath == null) return;
    final finalZipPath = zipPath.toLowerCase().endsWith('.zip') ? zipPath : '$zipPath.zip';

    // Start ZIP Export
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Đang tạo và mã hóa các tệp tin .cmt...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final archive = Archive();
      final tempDir = await Directory.systemTemp.createTemp('excel_cmt_zip_');

      for (final project in toExport) {
        final List<ThesisStudent> tstudents = [];
        for (final s in project.students) {
          final verdict = project.gvEvaluation.studentVerdicts.firstWhere(
            (v) => v.roll.toUpperCase() == s.roll.toUpperCase(),
            orElse: () => StudentVerdictModel(roll: s.roll),
          );
          tstudents.add(ThesisStudent(
            roll: s.roll,
            name: s.name,
            agreeToDefense: verdict.agreeToDefense ? 'x' : '',
            revisedForSecondDefense: verdict.revisedForSecondDefense ? 'x' : '',
            disagreeToDefense: verdict.disagreeToDefense ? 'x' : '',
            note: verdict.note,
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
          content: project.gvEvaluation.content,
          form: project.gvEvaluation.form,
          attitude: project.gvEvaluation.attitude,
          achievement: project.gvEvaluation.achievement,
          limitation: project.gvEvaluation.limitation,
          conclusion: project.gvEvaluation.conclusion,
          students: tstudents,
        );

        final fileName = '${project.groupCode}_${project.topicCode}.cmt';
        final filePath = p.join(tempDir.path, fileName);
        
        await _cmtExport.exportToFile(thesis: thesis, outputPath: filePath);

        // Read file bytes and add to zip archive
        final bytes = await File(filePath).readAsBytes();
        archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
      }

      final zipData = ZipEncoder().encode(archive);
      if (zipData != null) {
        await File(finalZipPath).writeAsBytes(zipData, flush: true);
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xuất thành công ${toExport.length} file .cmt vào ZIP:\n$finalZipPath'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Lỗi xuất ZIP'),
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
  }

  Future<void> _exportToExcel(ProjectListState state) async {
    final toExport = state.projects.where((p) => p.students.isNotEmpty).toList();
    if (toExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có đề tài nào để xuất Excel.')),
      );
      return;
    }

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Xuất file Excel danh sách đề tài',
      fileName: 'DanhSachDeTai.xlsx',
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
    if (path == null) return;
    
    final finalPath = path.toLowerCase().endsWith('.xlsx') ? path : '$path.xlsx';

    try {
      final excelExport = ExcelExportService();
      final bytes = await excelExport.generateExcelBytes(toExport);
      await File(finalPath).writeAsBytes(bytes, flush: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xuất thành công Excel vào:\n$finalPath'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Có lỗi xảy ra khi xuất Excel: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showClearEvaluationsDialog(WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa trắng dữ liệu nhận xét'),
        content: const Text(
          'Hành động này sẽ xóa sạch toàn bộ điểm, nhận xét, và kết luận bảo vệ của TẤT CẢ các nhóm đề tài.\n\n'
          'Chỉ có danh sách sinh viên và mã nhóm là được giữ lại. Bạn có chắc chắn muốn tiếp tục không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('HỦY BỎ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(projectListProvider.notifier).clearAllEvaluations();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã làm mới lại toàn bộ dữ liệu nhận xét!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('XÓA TRẮNG'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showPasswordPrompt() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đặt mật khẩu các file .cmt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nhập mật khẩu mã hóa cho các file nhận xét khóa luận .cmt.\n'
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
            child: const Text('TIẾP TỤC'),
          ),
        ],
      ),
    );
  }
}

class _MetadataHeaderPanel extends StatelessWidget {
  const _MetadataHeaderPanel({
    required this.state,
    required this.scheme,
    required this.t,
  });

  final ProjectListState state;
  final ColorScheme scheme;
  final TextTheme t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withOpacity(0.95),
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.dashboard_rounded, color: scheme.primary, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _MetaItem(icon: Icons.person_rounded, label: 'GVHD', value: state.teacher, t: t, scheme: scheme),
                _MetaItem(icon: Icons.calendar_month_rounded, label: 'Học kỳ', value: state.semester, t: t, scheme: scheme),
                _MetaItem(icon: Icons.code_rounded, label: 'Mã môn', value: state.subjectCode, t: t, scheme: scheme),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.t,
    required this.scheme,
  });

  final IconData icon;
  final String label;
  final String value;
  final TextTheme t;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(icon, size: 18, color: scheme.primary),
            ),
          ),
          TextSpan(
            text: '$label: ',
            style: t.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: scheme.onSurfaceVariant),
          ),
          TextSpan(
            text: value.isNotEmpty ? value : '(Chưa điền)',
            style: t.bodyMedium?.copyWith(
              color: value.isNotEmpty ? scheme.onSurface : scheme.onSurfaceVariant.withOpacity(0.5),
              fontStyle: value.isEmpty ? FontStyle.italic : null,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _FilterSearchBar extends StatelessWidget {
  const _FilterSearchBar({
    required this.searchQuery,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.scheme,
    required this.t,
  });

  final String searchQuery;
  final String statusFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final ColorScheme scheme;
  final TextTheme t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: scheme.surface.withOpacity(0.5),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Tìm kiếm theo nhóm, mã ĐT, sinh viên, tên ĐT...',
                prefixIcon: Icon(Icons.search_rounded),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: statusFilter,
              onChanged: (val) {
                if (val != null) onStatusChanged(val);
              },
              decoration: const InputDecoration(
                labelText: 'Trạng thái kiểm duyệt',
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              ),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('Tất cả trạng thái')),
                DropdownMenuItem(value: 'VALID', child: Text('VALID (Hợp lệ)')),
                DropdownMenuItem(value: 'MISSING_DATA', child: Text('MISSING_DATA (Thiếu thông tin)')),
                DropdownMenuItem(value: 'DUPLICATE', child: Text('DUPLICATE (Trùng SV)')),
                DropdownMenuItem(value: 'TOPIC_CONFLICT', child: Text('TOPIC_CONFLICT (Xung đột đề tài)')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectGridCard extends StatelessWidget {
  const _ProjectGridCard({
    required this.project,
    required this.originalIndex,
    required this.scheme,
    required this.t,
  });

  final ProjectModel project;
  final int originalIndex;
  final ColorScheme scheme;
  final TextTheme t;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusLabel = project.validationStatus;

    switch (project.validationStatus) {
      case 'VALID':
        statusColor = Colors.green;
        statusLabel = 'Hợp lệ';
        break;
      case 'DUPLICATE':
        statusColor = Colors.red;
        statusLabel = 'Trùng SV';
        break;
      case 'TOPIC_CONFLICT':
        statusColor = Colors.orange;
        statusLabel = 'Chưa có đề tài';
        break;
      case 'MISSING_DATA':
      default:
        statusColor = Colors.orange;
        statusLabel = 'Thiếu đánh giá';
        break;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => ProjectDetailScreen(projectIndex: originalIndex),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        project.groupCode.isNotEmpty ? project.groupCode : 'GROUP_UNKNOWN',
                        style: t.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.onSecondaryContainer,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      statusLabel,
                      style: t.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                project.topicCode,
                style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: project.titleVn.isNotEmpty 
                    ? Text(
                        project.titleVn,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                      )
                    : ListView.builder(
                        itemCount: project.students.length,
                        itemBuilder: (context, idx) {
                          final s = project.students[idx];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2.0),
                            child: Text(
                              '• ${s.name} (${s.roll})',
                              style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
              ),
              const Divider(height: 16),
              Row(
                children: [
                  Icon(Icons.people_alt_rounded, size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    '${project.students.length} sinh viên',
                    style: t.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomActionsBar extends StatelessWidget {
  const _BottomActionsBar({
    required this.onImportSurveys,
    required this.onExportAllCmt,
    required this.onExportExcel,
    required this.onClearEvaluations,
    required this.projectsCount,
    required this.scheme,
    required this.t,
  });

  final VoidCallback onImportSurveys;
  final VoidCallback onExportAllCmt;
  final VoidCallback onExportExcel;
  final VoidCallback onClearEvaluations;
  final int projectsCount;
  final ColorScheme scheme;
  final TextTheme t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withOpacity(0.95),
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Tổng cộng: $projectsCount nhóm đề tài',
            style: t.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
              Wrap(
                spacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: onClearEvaluations,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                    icon: const Icon(Icons.cleaning_services_rounded),
                    label: const Text('Xóa dữ liệu nhận xét'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onImportSurveys,
                    icon: const Icon(Icons.merge_type_rounded),
                    label: const Text('Nhập file Excel/Sheet'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onExportExcel,
                    icon: const Icon(Icons.table_chart_rounded),
                    label: const Text('Xuất Excel'),
                  ),
                  FilledButton.icon(
                    onPressed: onExportAllCmt,
                    icon: const Icon(Icons.archive_rounded),
                    label: const Text('XUẤT ZIP'),
                  ),
                ],
              ),
        ],
      ),
    );
  }
}
