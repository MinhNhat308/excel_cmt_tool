import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/sheet_field_labels.dart';
import '../models/de_tai_record.dart';
import '../models/fg_roster.dart';
import '../models/project_bundle.dart';
import '../models/thesis_comment.dart';
import '../services/batch_export_service.dart';
import '../utils/fugrade_password.dart';
import '../services/cmt_export_service.dart';
import '../services/fg_import_service.dart';
import '../services/google_sheet_service.dart';
import '../services/project_merge_service.dart';
import '../services/project_storage_service.dart';
import '../theme/app_theme.dart';

class ThesisWorkbenchScreen extends StatefulWidget {
  const ThesisWorkbenchScreen({super.key});

  @override
  State<ThesisWorkbenchScreen> createState() => _ThesisWorkbenchScreenState();
}

class _ThesisWorkbenchScreenState extends State<ThesisWorkbenchScreen> {
  final _fgImport = FgImportService();
  final _sheetImport = GoogleSheetService();
  final _merge = ProjectMergeService();
  final _storage = ProjectStorageService();
  final _batchExport = BatchExportService();
  final _cmtBinary = CmtExportService();

  final _sheetUrlCtrl = TextEditingController();

  ProjectBundle? _bundle;
  int? _selectedIndex;
  int _reloadGeneration = 0;
  bool _sheetLoading = false;
  String? _status;
  String? _fgFileName;
  String? _sheetLabel;

  @override
  void dispose() {
    _sheetUrlCtrl.dispose();
    super.dispose();
  }

  void _rebuildBundle() {
    final roster = _bundle?.roster;
    final topics = _bundle?.topics ?? [];
    if (roster == null) {
      setState(() {
        _bundle = topics.isEmpty
            ? null
            : ProjectBundle(
                topics: topics,
                sheetUrl: _sheetUrlCtrl.text.trim(),
              );
        _selectedIndex = null;
      });
      return;
    }
    setState(() {
      _bundle = _merge.merge(
        roster: roster,
        sheetTopics: topics,
        sheetUrl: _sheetUrlCtrl.text.trim(),
      );
      _reloadGeneration++;
      if (_selectedIndex == null && _bundle!.topics.isNotEmpty) {
        _selectedIndex = 0;
      } else if (_selectedIndex != null &&
          _selectedIndex! >= _bundle!.topics.length) {
        _selectedIndex = null;
      }
    });
  }

  Future<void> _importFg() async {
    final res = await _fgImport.pickAndImport();
    if (!mounted) return;
    if (res.error != null) {
      setState(() => _status = res.error);
      return;
    }
    if (res.roster == null) return;
    setState(() {
      _fgFileName = res.fileName;
      _bundle = ProjectBundle(
        roster: res.roster,
        topics: const [],
        sheetUrl: _sheetUrlCtrl.text.trim(),
      );
      _selectedIndex = null;
      _status = 'Đã import roster: ${res.roster!.students.length} SV, '
          '${res.roster!.groupCodes.length} nhóm.';
    });
    _rebuildBundle();
    final url = _sheetUrlCtrl.text.trim();
    if (url.isNotEmpty) {
      await _importSheetUrl(silent: true);
    }
  }

  Future<void> _importSheetUrl({bool silent = false}) async {
    final url = _sheetUrlCtrl.text.trim();
    if (url.isEmpty) {
      if (!silent) _snack('Chưa nhập link Google Sheet.');
      return;
    }
    setState(() => _sheetLoading = true);
    final res = await _sheetImport.importFromUrl(url);
    if (!mounted) return;
    setState(() => _sheetLoading = false);
    _applySheetResult(res, isReload: true);
  }

  Future<void> _importSheetFile() async {
    final res = await _sheetImport.pickLocalSheet();
    if (!mounted) return;
    _applySheetResult(res, isReload: true);
  }

  Future<void> _importCmt() async {
    if (kIsWeb) {
      _snack('Import .cmt chỉ hỗ trợ trên Windows.');
      return;
    }
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['cmt'],
    );
    if (pick == null || pick.files.isEmpty || pick.files.single.path == null) {
      return;
    }
    try {
      final thesis = await _cmtBinary.importFromFile(pick.files.single.path!);
      if (!mounted) return;

      var topics = List<DeTaiRecord>.from(_bundle?.topics ?? []);
      final maNhom =
          thesis.className.isNotEmpty ? thesis.className : '';

      var idx = -1;
      if (maNhom.isNotEmpty) {
        idx = topics.indexWhere((t) => FgRoster.groupsMatch(t.maNhom, maNhom));
      }
      if (idx < 0 &&
          _selectedIndex != null &&
          _selectedIndex! < topics.length) {
        idx = _selectedIndex!;
      }

      if (idx < 0) {
        final t = DeTaiRecord()..updateFromThesis(thesis);
        if (maNhom.isNotEmpty) t.maNhom = maNhom;
        topics.add(t);
        idx = topics.length - 1;
      } else {
        topics[idx].updateFromThesis(thesis);
        if (maNhom.isNotEmpty) topics[idx].maNhom = maNhom;
      }

      final roster = _bundle?.roster;
      if (roster != null) {
        topics[idx].mergeStudentsWithRoster(roster);
      }

      setState(() {
        _bundle = ProjectBundle(
          roster: roster,
          topics: topics,
          sheetUrl: _sheetUrlCtrl.text.trim(),
        );
        _selectedIndex = idx;
        _reloadGeneration++;
        _status =
            'Đã import .cmt · nhóm: ${topics[idx].maNhom} · '
            '${topics[idx].students.length} SV · '
            '${topics[idx].content.isNotEmpty ? "có nội dung" : ""}';
      });
      _rebuildBundle();
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Lỗi import .cmt: $e');
    }
  }

  void _applySheetResult(SheetImportResult res, {bool isReload = false}) {
    if (res.error != null) {
      setState(() => _status = res.error);
      return;
    }
    if (res.topics.isEmpty) return;
    setState(() {
      _sheetLabel = res.sourceLabel;
      _bundle = ProjectBundle(
        roster: _bundle?.roster,
        topics: res.topics,
        sheetUrl: _sheetUrlCtrl.text.trim(),
      );
      _selectedIndex = _bundle!.topics.isNotEmpty ? 0 : null;
      final cols = res.columnSummary != null ? '\n${res.columnSummary}' : '';
      final withTitles = res.topics
          .where((t) => t.titleVn.isNotEmpty || t.titleEn.isNotEmpty)
          .length;
      final withKl =
          res.topics.where((t) => t.content.isNotEmpty).length;
      _status = isReload
          ? 'Đã tải lại sheet: ${res.topics.length} đề tài · '
              '$withTitles có tên VN/EN · $withKl có nội dung KL.$cols'
          : 'Đã import ${res.topics.length} đề tài từ sheet · '
              '$withTitles có tên VN/EN · $withKl có nội dung KL.$cols';
    });
    _rebuildBundle();
  }

  Future<void> _loadProject() async {
    final path = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (path == null || path.files.single.path == null) return;
    try {
      final bundle = await _storage.loadJson(path.files.single.path!);
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _fgFileName = bundle.roster?.sourcePath;
        _sheetLabel = bundle.sheetUrl;
        if (bundle.sheetUrl.isNotEmpty) {
          _sheetUrlCtrl.text = bundle.sheetUrl;
        }
        _selectedIndex = bundle.topics.isNotEmpty ? 0 : null;
        _status = 'Đã mở dự án JSON.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Lỗi mở JSON: $e');
    }
  }

  Future<void> _save({required bool asFg}) async {
    if (_bundle == null || !_bundle!.isReady) {
      _snack('Cần import roster và Google Sheet trước.');
      return;
    }
    final ext = asFg ? 'fg' : 'json';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: asFg ? 'Lưu file .fg (FuGrade)' : 'Lưu dự án JSON',
      fileName: asFg ? 'thesis_project.fg' : 'thesis_project.json',
      type: FileType.custom,
      allowedExtensions: [ext],
    );
    if (path == null) return;
    try {
      final saved = ProjectBundle(
        roster: _bundle!.roster,
        topics: _bundle!.topics,
        sheetUrl: _sheetUrlCtrl.text.trim(),
        savedAt: DateTime.now(),
      );
      if (asFg) {
        await _storage.saveFg(saved, path);
      } else {
        await _storage.saveJson(saved, path);
      }
      if (!mounted) return;
      _snack(asFg ? 'Đã lưu file .fg' : 'Đã lưu JSON');
    } catch (e) {
      if (!mounted) return;
      _snack('Lỗi lưu: $e');
    }
  }

  Future<void> _exportOne() async {
    final topic = _selectedTopic;
    if (topic == null) return;
    if (kIsWeb) {
      _snack('Xuất .cmt chỉ hỗ trợ trên Windows.');
      return;
    }
    final name = _safeName(topic.maDeTai.isNotEmpty ? topic.maDeTai : topic.maNhom);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Xuất .cmt (có password)',
      fileName: '$name.cmt',
      type: FileType.custom,
      allowedExtensions: const ['cmt'],
    );
    if (path == null) return;
    final full = path.toLowerCase().endsWith('.cmt') ? path : '$path.cmt';
    try {
      await _batchExport.exportOne(topic, full);
      if (!mounted) return;
      _snack('Đã xuất .cmt: $full');
    } catch (e) {
      if (!mounted) return;
      _snack('Lỗi xuất: $e');
    }
  }

  Future<void> _exportAll() async {
    if (_bundle == null || _bundle!.topics.isEmpty) {
      _snack('Chưa có đề tài.');
      return;
    }
    if (kIsWeb) {
      _snack('Export all chỉ hỗ trợ trên Windows.');
      return;
    }
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export all — file ZIP chứa các .cmt',
      fileName: 'all_thesis_cmt.zip',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (path == null) return;
    try {
      final count = await _batchExport.exportAllToZip(
        bundle: _bundle!,
        zipPath: path,
      );
      if (!mounted) return;
      _snack('Đã xuất $count file .cmt vào ZIP (mở bằng WinRAR/7-Zip).');
    } on StateError catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (e) {
      if (!mounted) return;
      _snack('Lỗi export all: $e');
    }
  }

  DeTaiRecord? get _selectedTopic {
    if (_bundle == null || _selectedIndex == null) return null;
    final i = _selectedIndex!;
    if (i < 0 || i >= _bundle!.topics.length) return null;
    return _bundle!.topics[i];
  }

  void _updateSelected(void Function(DeTaiRecord t) fn) {
    final t = _selectedTopic;
    if (t == null) return;
    setState(() => fn(t));
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _safeName(String s) =>
      s.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.school_rounded, color: scheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nhận xét khóa luận'),
                  Text(
                    'Roster · Google Sheet · Xuất .cmt',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Mở dự án JSON',
            onPressed: _loadProject,
            icon: const Icon(Icons.folder_open_rounded),
          ),
          IconButton(
            tooltip: 'Hướng dẫn',
            onPressed: () => _showHelp(context),
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: AppTheme.pageBackground(context),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _ImportPanel(
                  sheetUrlCtrl: _sheetUrlCtrl,
                  fgFileName: _fgFileName,
                  sheetLabel: _sheetLabel,
                  status: _status,
                  bundle: _bundle,
                  onImportFg: _importFg,
                  onImportSheetUrl: () => _importSheetUrl(),
                  onImportSheetFile: _importSheetFile,
                  onImportCmt: _importCmt,
                  sheetLoading: _sheetLoading,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _bundle == null ||
                          (_bundle!.topics.isEmpty && _bundle!.roster == null)
                      ? _EmptyState(scheme: scheme, hasFg: _bundle?.roster != null)
                      : wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: 280,
                                  child: _TopicList(
                                    topics: _bundle!.topics,
                                    selectedIndex: _selectedIndex,
                                    onSelect: (i) =>
                                        setState(() => _selectedIndex = i),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _TopicDetail(
                                    key: ValueKey(
                                      'detail-$_reloadGeneration-$_selectedIndex',
                                    ),
                                    topic: _selectedTopic,
                                    roster: _bundle?.roster,
                                    reloadGeneration: _reloadGeneration,
                                    onChanged: _updateSelected,
                                    onSaveJson: () => _save(asFg: false),
                                    onSaveFg: () => _save(asFg: true),
                                    onExport: _exportOne,
                                    onExportAll: _exportAll,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _TopicList(
                                  topics: _bundle!.topics,
                                  selectedIndex: _selectedIndex,
                                  onSelect: (i) =>
                                      setState(() => _selectedIndex = i),
                                  height: 200,
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: _TopicDetail(
                                    key: ValueKey(
                                      'detail-$_reloadGeneration-$_selectedIndex',
                                    ),
                                    topic: _selectedTopic,
                                    roster: _bundle?.roster,
                                    reloadGeneration: _reloadGeneration,
                                    onChanged: _updateSelected,
                                    onSaveJson: () => _save(asFg: false),
                                    onSaveFg: () => _save(asFg: true),
                                    onExport: _exportOne,
                                    onExportAll: _exportAll,
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
    );
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: MediaQuery.paddingOf(ctx).bottom + 24,
          top: 8,
        ),
        child: const SingleChildScrollView(
          child: Text(
            '1) Import roster (.fg / .xlsx)\n'
            '2) Import Google Sheet hoặc CSV/XLSX\n'
            '3) Chọn đề tài, chỉnh nội dung\n'
            '4) Save JSON / .fg\n'
            '5) Export .cmt / Export all',
          ),
        ),
      ),
    );
  }
}

class _ImportPanel extends StatefulWidget {
  const _ImportPanel({
    required this.sheetUrlCtrl,
    required this.fgFileName,
    required this.sheetLabel,
    required this.status,
    required this.bundle,
    required this.onImportFg,
    required this.onImportSheetUrl,
    required this.onImportSheetFile,
    required this.onImportCmt,
    this.sheetLoading = false,
  });

  final TextEditingController sheetUrlCtrl;
  final String? fgFileName;
  final String? sheetLabel;
  final String? status;
  final ProjectBundle? bundle;
  final VoidCallback onImportFg;
  final VoidCallback onImportSheetUrl;
  final VoidCallback onImportSheetFile;
  final VoidCallback onImportCmt;
  final bool sheetLoading;

  @override
  State<_ImportPanel> createState() => _ImportPanelState();
}

class _ImportPanelState extends State<_ImportPanel> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.bundle == null || !widget.bundle!.isReady;
  }

  @override
  void didUpdateWidget(covariant _ImportPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bundle?.isReady == true && oldWidget.bundle?.isReady != true) {
      _isExpanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ready = widget.bundle?.isReady ?? false;
    return DecoratedBox(
      decoration: AppTheme.glassCard(context),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_upload_rounded, color: scheme.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Nhập dữ liệu',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(_isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  tooltip: _isExpanded ? 'Thu gọn' : 'Mở rộng',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: widget.onImportFg,
                        icon: const Icon(Icons.folder_shared_rounded, size: 20),
                        label: const Text('Roster (.fg)'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.onImportSheetFile,
                        icon: const Icon(Icons.table_chart_rounded, size: 20),
                        label: const Text('Sheet file'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.onImportCmt,
                        icon: const Icon(Icons.upload_file_rounded, size: 20),
                        label: const Text('Import .cmt'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: widget.sheetUrlCtrl,
                    decoration: InputDecoration(
                      labelText: 'Link Google Sheet',
                      hintText: 'https://docs.google.com/spreadsheets/d/...',
                      prefixIcon: Icon(Icons.link_rounded, color: scheme.primary),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: widget.sheetLoading ? null : widget.onImportSheetUrl,
                    icon: widget.sheetLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.primary,
                            ),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: Text(widget.sheetLoading ? 'Đang tải sheet...' : 'Tải / tải lại Sheet'),
                  ),
                ],
              ),
              crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
            if (widget.fgFileName != null || widget.sheetLabel != null || widget.bundle?.roster != null) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.fgFileName != null)
                    _InfoChip(
                      icon: Icons.badge_rounded,
                      label: 'FG: ${widget.fgFileName}',
                      color: scheme.primaryContainer,
                    ),
                  if (widget.sheetLabel != null)
                    _InfoChip(
                      icon: Icons.grid_on_rounded,
                      label: widget.sheetLabel!,
                      color: scheme.secondaryContainer,
                    ),
                  if (widget.bundle?.roster != null)
                    _InfoChip(
                      icon: Icons.people_rounded,
                      label:
                          '${widget.bundle!.roster!.students.length} SV · ${widget.bundle!.topics.length} đề tài'
                          '${ready ? " · ${widget.bundle!.matchedTopicCount} ghép" : ""}',
                      color: scheme.tertiaryContainer,
                    ),
                ],
              ),
            ],
            if (widget.status != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.status!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.scheme, required this.hasFg});

  final ColorScheme scheme;
  final bool hasFg;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFg ? Icons.table_view_rounded : Icons.rocket_launch_rounded,
              size: 56,
              color: scheme.primary.withOpacity(0.75),
            ),
            const SizedBox(height: 16),
            Text(
              hasFg ? 'Đã có roster' : 'Bắt đầu nhập liệu',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFg
                  ? 'Import Google Sheet (link hoặc file CSV/XLSX) để ghép cột với đề tài.'
                  : 'Import roster (.fg) rồi Sheet — cột form trùng với file Google Sheet của bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicList extends StatelessWidget {
  const _TopicList({
    required this.topics,
    required this.selectedIndex,
    required this.onSelect,
    this.height,
  });

  final List<DeTaiRecord> topics;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final list = ListView.builder(
      itemCount: topics.length,
      itemBuilder: (context, i) {
        final t = topics[i];
        final selected = selectedIndex == i;
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Material(
            color: selected
                ? scheme.primaryContainer.withOpacity(0.55)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: ListTile(
              selected: selected,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: selected
                    ? BorderSide(color: scheme.primary.withOpacity(0.45))
                    : BorderSide.none,
              ),
              title: Text(
                t.displayTitle,
                maxLines: 3,
                softWrap: true,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '${SheetFieldLabels.maDeTai}: ${t.maDeTai.isEmpty ? "—" : t.maDeTai}\n'
                '${SheetFieldLabels.maNhom}: ${t.maNhom} · ${t.students.length} SV',
                softWrap: true,
              ),
              leading: CircleAvatar(
                backgroundColor: selected
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                foregroundColor:
                    selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                child: Text('${i + 1}'),
              ),
              trailing: t.students.isEmpty
                  ? Icon(Icons.warning_amber_rounded,
                      color: scheme.tertiary, size: 22)
                  : Icon(Icons.chevron_right_rounded,
                      color: scheme.outline),
              onTap: () => onSelect(i),
            ),
          ),
        );
      },
    );
    return Card(
      child: height != null ? SizedBox(height: height, child: list) : list,
    );
  }
}

class _TopicDetail extends StatefulWidget {
  const _TopicDetail({
    super.key,
    required this.topic,
    required this.roster,
    required this.onChanged,
    required this.onSaveJson,
    required this.onSaveFg,
    required this.onExport,
    required this.onExportAll,
    required this.reloadGeneration,
  });

  final DeTaiRecord? topic;
  final FgRoster? roster;
  final int reloadGeneration;
  final void Function(void Function(DeTaiRecord t) fn) onChanged;
  final VoidCallback onSaveJson;
  final VoidCallback onSaveFg;
  final VoidCallback onExport;
  final VoidCallback onExportAll;

  @override
  State<_TopicDetail> createState() => _TopicDetailState();
}

class _TopicDetailState extends State<_TopicDetail> {
  final _fields = <String, TextEditingController>{};
  final _formScrollCtrl = ScrollController();
  bool _passwordVisible = false;

  @override
  void didUpdateWidget(covariant _TopicDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadGeneration != widget.reloadGeneration ||
        oldWidget.topic != widget.topic) {
      _syncControllers();
    }
  }

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  void _syncControllers() {
    final t = widget.topic;
    final keys = [
      'maDeTai', 'maNhom', 'titleVn', 'titleEn',
      'content', 'form', 'attitude', 'achievement', 'limitation', 'password',
    ];
    if (t == null) {
      for (final c in _fields.values) {
        c.dispose();
      }
      _fields.clear();
      return;
    }
    final pw = t.password;
    final values = {
      'maDeTai': t.maDeTai,
      'maNhom': t.maNhom,
      'titleVn': t.titleVn,
      'titleEn': t.titleEn,
      'content': t.content,
      'form': t.form,
      'attitude': t.attitude,
      'achievement': t.achievement,
      'limitation': t.limitation,
      'password': FugradePassword.looksLikeMd5(pw) ? '' : pw,
    };
    for (final k in keys) {
      _fields.putIfAbsent(k, () => TextEditingController());
      if (_fields[k]!.text != values[k]) {
        _fields[k]!.text = values[k] ?? '';
      }
    }
  }

  @override
  void dispose() {
    _formScrollCtrl.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _scrollableForm(Widget child, {EdgeInsetsGeometry? padding}) {
    return Scrollbar(
      controller: _formScrollCtrl,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _formScrollCtrl,
        padding: padding,
        child: child,
      ),
    );
  }

  void _bind(String key, void Function(DeTaiRecord t, String v) set) {
    widget.onChanged((t) => set(t, _fields[key]!.text));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.topic;
    if (t == null) {
      return DecoratedBox(
        decoration: AppTheme.glassCard(context),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('Chọn một đề tài trong danh sách bên trái.'),
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: AppTheme.glassCard(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide = constraints.maxWidth >= 760;
            final topicFields = _topicFieldsColumn(context, t);
            final studentPanel = _StudentDefensePanel(
              students: t.students,
              onStudentChanged: _notifyStudentChange,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: sideBySide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 45,
                              child: _scrollableForm(
                                topicFields,
                                padding: const EdgeInsets.only(right: 8),
                              ),
                            ),
                            VerticalDivider(
                              width: 1,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant,
                            ),
                            Expanded(
                              flex: 55,
                              child: studentPanel,
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Flexible(
                              flex: 45,
                              child: _scrollableForm(topicFields),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              flex: 55,
                              child: studentPanel,
                            ),
                          ],
                        ),
                ),
                const Divider(height: 28),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: widget.onExport,
                      icon: const Icon(Icons.file_download_rounded),
                      label: const Text('Xuất .cmt'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: widget.onExportAll,
                      icon: const Icon(Icons.folder_zip_rounded),
                      label: const Text('Xuất tất cả (ZIP)'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onSaveJson,
                      icon: const Icon(Icons.data_object_rounded),
                      label: const Text('Lưu JSON'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onSaveFg,
                      icon: const Icon(Icons.lock_rounded),
                      label: const Text('Lưu .fg'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _notifyStudentChange() {
    widget.onChanged((t) {});
  }

  Widget _topicFieldsColumn(BuildContext context, DeTaiRecord t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.displayTitle,
          softWrap: true,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
        ),
        const SizedBox(height: 16),
        _sectionTitle(context, Icons.article_outlined, 'Thông tin đề tài'),
        _row(SheetFieldLabels.maDeTai, 'maDeTai', 1, (x, v) => x.maDeTai = v),
        _row(SheetFieldLabels.maNhom, 'maNhom', 1, (x, v) {
          x.maNhom = v;
          if (widget.roster != null) {
            x.attachStudentsFromRoster(widget.roster!);
          }
        }),
        _row(SheetFieldLabels.titleVn, 'titleVn', 2, (x, v) => x.titleVn = v),
        _row(SheetFieldLabels.titleEn, 'titleEn', 2, (x, v) => x.titleEn = v),
        const SizedBox(height: 8),
        _sectionTitle(context, Icons.fact_check_outlined, 'Kết luận (cột Sheet)'),
        _row(SheetFieldLabels.content, 'content', 4, (x, v) => x.content = v),
        _row(SheetFieldLabels.form, 'form', 2, (x, v) => x.form = v),
        _row(SheetFieldLabels.attitude, 'attitude', 2, (x, v) => x.attitude = v),
        _row(SheetFieldLabels.achievement, 'achievement', 2,
            (x, v) => x.achievement = v),
        _row(SheetFieldLabels.limitation, 'limitation', 3,
            (x, v) => x.limitation = v),
        const SizedBox(height: 8),
        _sectionTitle(context, Icons.key_rounded, SheetFieldLabels.cmtPassword),
        _passwordField(context),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, IconData icon, String title) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                    letterSpacing: 0.3,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordField(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasStoredMd5 = widget.topic != null &&
        FugradePassword.looksLikeMd5(widget.topic!.password) &&
        _fields['password']!.text.isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: _fields['password']!,
        obscureText: !_passwordVisible,
        onChanged: (v) {
          widget.onChanged((x) {
            if (v.trim().isNotEmpty) {
              x.password = v;
            } else if (!hasStoredMd5) {
              x.password = '';
            }
          });
        },
        decoration: InputDecoration(
          labelText: SheetFieldLabels.cmtPassword,
          hintText: 'Để trống = mặc định "1"',
          prefixIcon: Icon(Icons.lock_outline_rounded, color: scheme.primary),
          suffixIcon: IconButton(
            tooltip: _passwordVisible ? 'Ẩn' : 'Hiện',
            onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
            icon: Icon(
              _passwordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            ),
          ),
          isDense: true,
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String key,
    int minLines,
    void Function(DeTaiRecord t, String v) set, {
    int? maxLines,
  }) {
    final ctrl = _fields[key]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        onChanged: (_) => _bind(key, set),
        minLines: minLines,
        maxLines: maxLines ?? (minLines > 1 ? 16 : 3),
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: minLines > 1,
          isDense: minLines == 1,
        ),
      ),
    );
  }
}

class _StudentDefensePanel extends StatefulWidget {
  const _StudentDefensePanel({
    required this.students,
    required this.onStudentChanged,
  });

  final List<ThesisStudent> students;
  final VoidCallback onStudentChanged;

  @override
  State<_StudentDefensePanel> createState() => _StudentDefensePanelState();
}

class _StudentDefensePanelState extends State<_StudentDefensePanel> {
  final _verticalScrollCtrl = ScrollController();
  final _horizontalScrollCtrl = ScrollController();

  @override
  void dispose() {
    _verticalScrollCtrl.dispose();
    _horizontalScrollCtrl.dispose();
    super.dispose();
  }

  static const _headers = [
    '#',
    'Roll',
    'Name',
    'Agree_to_defense',
    'Revised_for_the_second_defense',
    'Disagree_to_defense',
    'Note',
  ];

  static const _minTableWidth = 820.0;

  @override
  Widget build(BuildContext context) {
    final students = widget.students;
    final scheme = Theme.of(context).colorScheme;
    final border = TableBorder.all(color: scheme.outlineVariant);
    final headerStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.25,
        );
    const cellPad = EdgeInsets.symmetric(horizontal: 8, vertical: 8);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Text(
              'Sinh viên bảo vệ (${students.length}) — '
              'Mỗi cột Agree / Revised / Disagree: x hoặc X, để trống nếu không áp dụng',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (students.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Chưa có SV — kiểm tra mã nhóm.',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            )
          else
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tableWidth = constraints.maxWidth < _minTableWidth
                      ? _minTableWidth
                      : constraints.maxWidth;
                  return Scrollbar(
                    controller: _verticalScrollCtrl,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _verticalScrollCtrl,
                      padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                      child: SingleChildScrollView(
                        controller: _horizontalScrollCtrl,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: tableWidth,
                          child: Table(
                              border: border,
                              defaultVerticalAlignment:
                                  TableCellVerticalAlignment.top,
                              columnWidths: {
                                0: const FixedColumnWidth(36),
                                1: const FixedColumnWidth(100),
                                2: FlexColumnWidth(2.2),
                                3: const FixedColumnWidth(52),
                                4: const FixedColumnWidth(100),
                                5: const FixedColumnWidth(52),
                                6: FlexColumnWidth(2.5),
                              },
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest,
                                  ),
                                  children: _headers
                                      .map(
                                        (h) => Padding(
                                          padding: cellPad,
                                          child: Text(
                                            h,
                                            style: headerStyle,
                                            softWrap: true,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                                ...students.asMap().entries.map(
                                      (e) => _StudentDefenseTableRow.build(
                                        context: context,
                                        index: e.key,
                                        student: e.value,
                                        onChanged: widget.onStudentChanged,
                                        cellPad: cellPad,
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _StudentDefenseTableRow {
  static TableRow build({
    required BuildContext context,
    required int index,
    required ThesisStudent student,
    required VoidCallback onChanged,
    required EdgeInsets cellPad,
  }) {
    Widget readCell(String text) => Padding(
          padding: cellPad,
          child: SelectableText(
            text,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );

    return TableRow(
      children: [
        Padding(
          padding: cellPad,
          child: Text(
            '${index + 1}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        readCell(student.roll),
        readCell(student.name),
        Padding(
          padding: cellPad,
          child: _DefenseMarkCell(
            value: student.agreeToDefense,
            onCommit: (v) {
              student.agreeToDefense = v;
              onChanged();
            },
          ),
        ),
        Padding(
          padding: cellPad,
          child: _DefenseMarkCell(
            value: student.revisedForSecondDefense,
            onCommit: (v) {
              student.revisedForSecondDefense = v;
              onChanged();
            },
          ),
        ),
        Padding(
          padding: cellPad,
          child: _DefenseMarkCell(
            value: student.disagreeToDefense,
            onCommit: (v) {
              student.disagreeToDefense = v;
              onChanged();
            },
          ),
        ),
        Padding(
          padding: cellPad,
          child: _DefenseNoteCell(
            value: student.note,
            onChanged: (v) {
              student.note = v;
              onChanged();
            },
          ),
        ),
      ],
    );
  }
}

class _DefenseMarkCell extends StatefulWidget {
  const _DefenseMarkCell({
    required this.value,
    required this.onCommit,
  });

  final String value;
  final ValueChanged<String> onCommit;

  @override
  State<_DefenseMarkCell> createState() => _DefenseMarkCellState();
}

class _DefenseMarkCellState extends State<_DefenseMarkCell> {
  late final TextEditingController _ctrl;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _display(widget.value));
  }

  @override
  void didUpdateWidget(covariant _DefenseMarkCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final d = _display(widget.value);
    if (oldWidget.value != widget.value && _ctrl.text != d) {
      _ctrl.text = d;
      _errorText = null;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _display(String v) =>
      ThesisStudent.isDefenseMark(v) ? 'x' : '';

  void _showInvalidDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Input conclusion'),
        content: const Text(
          'Invalid value!\nThe value must be x or X!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _rejectInvalid(String attempted) {
    final revert = _display(widget.value);
    setState(() => _errorText = 'Chỉ x hoặc X');
    _ctrl.value = TextEditingValue(
      text: revert,
      selection: TextSelection.collapsed(offset: revert.length),
    );
    _showInvalidDialog();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          attempted.isEmpty
              ? 'Giá trị phải là x hoặc X (hoặc để trống).'
              : '"$attempted" không hợp lệ — chỉ x hoặc X.',
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleChanged(String text) {
    if (text.isEmpty) {
      setState(() => _errorText = null);
      widget.onCommit('');
      return;
    }
    final normalized = ThesisStudent.normalizeDefenseMark(text);
    if (normalized == null) {
      _rejectInvalid(text);
      return;
    }
    setState(() => _errorText = null);
    if (text != 'x') {
      _ctrl.value = const TextEditingValue(
        text: 'x',
        selection: TextSelection.collapsed(offset: 1),
      );
    }
    widget.onCommit('x');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasError = _errorText != null;
    final isEmpty =
        !ThesisStudent.isDefenseMark(widget.value) && _ctrl.text.isEmpty;

    return SizedBox(
      width: 56,
      child: TextField(
        controller: _ctrl,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
        decoration: InputDecoration(
          filled: true,
          fillColor: isEmpty && !hasError
              ? Colors.white
              : (hasError
                  ? scheme.errorContainer.withValues(alpha: 0.35)
                  : scheme.primaryContainer.withValues(alpha: 0.25)),
          counterText: '',
          hintText: '',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          errorText: _errorText,
          errorStyle: const TextStyle(fontSize: 10, height: 1.1),
          errorMaxLines: 2,
          border: const OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: hasError
                  ? scheme.error
                  : scheme.outlineVariant.withValues(alpha: 0.6),
              width: hasError ? 2 : 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: hasError ? scheme.error : scheme.primary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: scheme.error, width: 2),
          ),
        ),
        onChanged: _handleChanged,
        onTapOutside: (_) {
          if (_errorText != null) _rejectInvalid(_ctrl.text);
        },
      ),
    );
  }
}

class _DefenseNoteCell extends StatefulWidget {
  const _DefenseNoteCell({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_DefenseNoteCell> createState() => _DefenseNoteCellState();
}

class _DefenseNoteCellState extends State<_DefenseNoteCell> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _DefenseNoteCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _ctrl,
      style: Theme.of(context).textTheme.bodySmall,
      minLines: 1,
      maxLines: 8,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      onChanged: widget.onChanged,
    );
  }
}

