import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/de_tai_record.dart';
import '../models/fg_roster.dart';
import '../models/project_bundle.dart';
import '../services/batch_export_service.dart';
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
      final withNx = res.topics.where((t) => t.nhanXetSv.isNotEmpty).length;
      _status = isReload
          ? 'Đã tải lại sheet: ${res.topics.length} đề tài · '
              '$withTitles có tên VN/EN · $withNx có nhận xét.$cols'
          : 'Đã import ${res.topics.length} đề tài từ sheet · '
              '$withTitles có tên VN/EN · $withNx có nhận xét.$cols';
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
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Nhận xét KL — Roster + Sheet'),
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
        decoration: AppTheme.pageGradient(context),
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
                                  width: 320,
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

class _ImportPanel extends StatelessWidget {
  const _ImportPanel({
    required this.sheetUrlCtrl,
    required this.fgFileName,
    required this.sheetLabel,
    required this.status,
    required this.bundle,
    required this.onImportFg,
    required this.onImportSheetUrl,
    required this.onImportSheetFile,
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
  final bool sheetLoading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ready = bundle?.isReady ?? false;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onImportFg,
                  icon: const Icon(Icons.group_rounded),
                  label: const Text('Import roster'),
                ),
                OutlinedButton.icon(
                  onPressed: onImportSheetFile,
                  icon: const Icon(Icons.table_rows_rounded),
                  label: const Text('Sheet file'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: sheetUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'Link Google Sheet',
                hintText: 'https://docs.google.com/spreadsheets/d/...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: sheetLoading ? null : onImportSheetUrl,
              icon: sheetLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_download_rounded),
              label: Text(sheetLoading ? 'Đang tải...' : 'Tải / tải lại Sheet'),
            ),
            if (fgFileName != null || sheetLabel != null) ...[
              const SizedBox(height: 10),
              Text(
                [
                  if (fgFileName != null) 'FG: $fgFileName',
                  if (sheetLabel != null) 'Sheet: $sheetLabel',
                  if (bundle?.roster != null)
                    '${bundle!.roster!.students.length} SV · ${bundle!.topics.length} đề tài'
                    '${ready ? " · ${bundle!.matchedTopicCount} đã ghép SV" : ""}',
                ].join('\n'),
                style: TextStyle(color: scheme.primary, fontSize: 13),
              ),
            ],
            if (status != null) ...[
              const SizedBox(height: 8),
              Text(status!, style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
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
      child: Text(
        hasFg
            ? 'Đã có roster. Hãy import Google Sheet (hoặc CSV/XLSX).'
            : 'Import roster (Excel/JSON) và Google Sheet để bắt đầu.',
        textAlign: TextAlign.center,
        style: TextStyle(color: scheme.onSurfaceVariant),
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
        return ListTile(
          selected: selected,
          title: Text(
            t.displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            'Mã ĐT: ${t.maDeTai.isEmpty ? "—" : t.maDeTai} · Nhóm: ${t.maNhom} · '
            '${t.students.length} SV',
          ),
          leading: CircleAvatar(
            child: Text('${i + 1}'),
          ),
          trailing: t.students.isEmpty
              ? const Icon(Icons.warning_amber_rounded, color: Colors.orange)
              : null,
          onTap: () => onSelect(i),
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
      'maDeTai', 'maNhom', 'titleVn', 'titleEn', 'danhGia', 'nhanXetSv',
      'content', 'form', 'attitude', 'achievement', 'limitation', 'password',
    ];
    if (t == null) {
      for (final c in _fields.values) {
        c.dispose();
      }
      _fields.clear();
      return;
    }
    final values = {
      'maDeTai': t.maDeTai,
      'maNhom': t.maNhom,
      'titleVn': t.titleVn,
      'titleEn': t.titleEn,
      'danhGia': t.danhGia,
      'nhanXetSv': t.nhanXetSv,
      'content': t.content,
      'form': t.form,
      'attitude': t.attitude,
      'achievement': t.achievement,
      'limitation': t.limitation,
      'password': t.password,
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
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _bind(String key, void Function(DeTaiRecord t, String v) set) {
    widget.onChanged((t) => set(t, _fields[key]!.text));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.topic;
    if (t == null) {
      return const Card(
        child: Center(child: Text('Chọn một đề tài trong danh sách.')),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.displayTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              _row('Mã đề tài', 'maDeTai', 1,
                  (x, v) => x.maDeTai = v),
              _row('Mã nhóm', 'maNhom', 1, (x, v) {
                x.maNhom = v;
                if (widget.roster != null) {
                  x.attachStudentsFromRoster(widget.roster!);
                }
              }),
              _row('Tên VN', 'titleVn', 1, (x, v) => x.titleVn = v),
              _row('Tên EN', 'titleEn', 1, (x, v) => x.titleEn = v),
              _row('Đánh giá', 'danhGia', 2, (x, v) => x.danhGia = v),
              _row('Nhận xét (góc nhìn SV)', 'nhanXetSv', 4,
                  (x, v) => x.nhanXetSv = v),
              _row('Nội dung', 'content', 3, (x, v) => x.content = v),
              _row('Hình thức', 'form', 1, (x, v) => x.form = v),
              _row('Thái độ', 'attitude', 1, (x, v) => x.attitude = v),
              _row('Mức độ đạt', 'achievement', 1,
                  (x, v) => x.achievement = v),
              _row('Hạn chế', 'limitation', 2, (x, v) => x.limitation = v),
              _row('Password .cmt', 'password', 1, (x, v) => x.password = v),
              const SizedBox(height: 12),
              Text(
                'Sinh viên (${t.students.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              if (t.students.isEmpty)
                const Text(
                  'Chưa ghép SV — kiểm tra mã nhóm khớp roster.',
                  style: TextStyle(color: Colors.orange),
                )
              else
                ...t.students.map(
                  (s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• ${s.roll} — ${s.name}'),
                  ),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: widget.onExport,
                    icon: const Icon(Icons.save_alt_rounded),
                    label: const Text('Export .cmt'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: widget.onExportAll,
                    icon: const Icon(Icons.archive_rounded),
                    label: const Text('Export all (ZIP)'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onSaveJson,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save JSON'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onSaveFg,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save .fg'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String key,
    int maxLines,
    void Function(DeTaiRecord t, String v) set,
  ) {
    final ctrl = _fields[key]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        onChanged: (_) => _bind(key, set),
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
