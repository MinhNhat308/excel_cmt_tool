import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/de_tai_meta.dart';
import '../models/thesis_comment.dart';
import '../models/tieu_chi_row.dart';
import '../services/cmt_export_service.dart';
import '../services/excel_import_service.dart';
import '../services/write_utf8_file.dart';
import '../services/nhan_xet_generator.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _excel = ExcelImportService();
  final _generator = NhanXetGenerator();
  final _cmtExport = CmtExportService();

  String? _fileName;
  DeTaiMeta _meta = const DeTaiMeta();
  ThesisComment? _thesis;
  List<TieuChiRow> _rows = [];
  String _report = '';
  String? _parseError;

  Future<void> _pickExcel() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.single;
    final bytes = f.bytes;
    if (bytes == null) {
      setState(() => _parseError = 'Không đọc được nội dung file.');
      return;
    }
    setState(() {
      _fileName = f.name;
      _parseError = null;
    });
    final res = _excel.decodeBytes(bytes);
    setState(() {
      _thesis = res.thesis;
      _meta = res.meta;
      _rows = res.rows;
      _parseError = res.error;
      if (res.error != null) {
        _report = '';
      } else if (res.thesis != null) {
        _report = res.thesis!.toPreviewText();
      } else {
        _report = _generator.buildFullReport(meta: res.meta, rows: res.rows);
      }
    });
  }

  Future<void> _export(String ext) async {
    if (ext == 'cmt') {
      if (_thesis == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chọn file Excel nhóm khóa luận (Roll, Name) trước.'),
          ),
        );
        return;
      }
    } else if (_report.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có nội dung để xuất.')),
      );
      return;
    }

    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: _report));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Web: chỉ hỗ trợ xuất .cmt trên Windows.')),
      );
      return;
    }

    final name = (_fileName ?? 'nhan_xet')
        .replaceAll(RegExp(r'\.xlsx$', caseSensitive: false), '');
    final path = await FilePicker.platform.saveFile(
      dialogTitle: ext == 'cmt' ? 'Lưu file .cmt (binary)' : 'Lưu file nhận xét',
      fileName: '$name.$ext',
      type: FileType.custom,
      allowedExtensions: [ext],
    );
    if (path == null) return;
    final full = path.toLowerCase().endsWith('.$ext') ? path : '$path.$ext';
    try {
      if (ext == 'cmt') {
        await _cmtExport.exportToFile(thesis: _thesis!, outputPath: full);
      } else {
        await writeUtf8File(full, _report);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ext == 'cmt'
                ? 'Đã xuất file .cmt (binary): $full'
                : 'Đã lưu: $full',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xuất file: $e')),
      );
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _report));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép nội dung nhận xét.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Nhận xét đề tài từ Excel'),
        actions: [
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
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _HeroCard(
                      fileName: _fileName,
                      onPick: _pickExcel,
                      scheme: scheme,
                    ),
                    const SizedBox(height: 16),
                    if (_parseError != null)
                      _ErrorBanner(message: _parseError!)
                    else if (_thesis != null) ...[
                      _ThesisPreviewCard(thesis: _thesis!, scheme: scheme),
                      const SizedBox(height: 16),
                    ] else if (_rows.isNotEmpty) ...[
                      _MetaCard(meta: _meta, scheme: scheme),
                      const SizedBox(height: 16),
                      _PreviewCard(rows: _rows, scheme: scheme),
                      const SizedBox(height: 16),
                    ],
                    _ReportCard(
                      text: _report,
                      scheme: scheme,
                      onCopy: _copy,
                      onExportCmt: () => _export('cmt'),
                      onExportTxt: () => _export('txt'),
                    ),
                  ]),
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
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            bottom: MediaQuery.paddingOf(ctx).bottom + 24,
            top: 8,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Định dạng Excel gợi ý',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Định dạng nhóm khóa luận:\n\n'
                  '1) Dòng tiêu đề gồm: Roll, Name, Tên KL (VN/EN), Nội dung, '
                  'Hình thức, Thái độ, Mức độ đạt, Hạn chế…\n\n'
                  '2) Các dòng sau: mỗi dòng 1 sinh viên (Roll + Name).\n'
                  '   Các cột còn lại dùng chung cho cả nhóm (ô merge cũng được).\n\n'
                  '3) (Tùy chọn) Phía trên header: Giảng viên, Mã môn, Lớp, Học kỳ…\n\n'
                  'Xuất .cmt: file binary (serialize .NET), cùng kiểu file mẫu thầy gửi.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.fileName,
    required this.onPick,
    required this.scheme,
  });

  final String? fileName;
  final VoidCallback onPick;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.table_chart_rounded, color: scheme.primary, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đọc Excel nhóm KL → xuất .cmt',
                        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chọn file Excel nhóm khóa luận (Roll, Name + trường chung).',
                        style: t.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Chọn file Excel (.xlsx)'),
            ),
            if (fileName != null) ...[
              const SizedBox(height: 12),
              Text(
                'Đang mở: $fileName',
                style: t.bodySmall?.copyWith(color: scheme.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer.withOpacity(0.9),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: scheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThesisPreviewCard extends StatelessWidget {
  const _ThesisPreviewCard({required this.thesis, required this.scheme});

  final ThesisComment thesis;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final shared = <String>[
      if (thesis.titleVn.isNotEmpty) 'Tên VN: ${thesis.titleVn}',
      if (thesis.titleEn.isNotEmpty) 'Tên EN: ${thesis.titleEn}',
      if (thesis.content.isNotEmpty) 'Nội dung: ${thesis.content}',
      if (thesis.form.isNotEmpty) 'Hình thức: ${thesis.form}',
      if (thesis.attitude.isNotEmpty) 'Thái độ: ${thesis.attitude}',
      if (thesis.achievement.isNotEmpty) 'Mức độ đạt: ${thesis.achievement}',
      if (thesis.limitation.isNotEmpty) 'Hạn chế: ${thesis.limitation}',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.groups_rounded, color: scheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Nhóm ${thesis.students.length} sinh viên',
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            if (shared.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...shared.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line),
                ),
              ),
            ],
            const SizedBox(height: 12),
            ...thesis.students.map(
              (s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('• ${s.roll} — ${s.name}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.meta, required this.scheme});

  final DeTaiMeta meta;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    if (!meta.hasAny) return const SizedBox.shrink();
    final lines = <String>[];
    if (meta.tenDeTai.isNotEmpty) lines.add('Đề tài: ${meta.tenDeTai}');
    if (meta.tenSinhVien.isNotEmpty) lines.add('Sinh viên: ${meta.tenSinhVien}');
    if (meta.maLop.isNotEmpty) lines.add('Lớp: ${meta.maLop}');
    if (meta.nguoiDanhGia.isNotEmpty) {
      lines.add('Người đánh giá: ${meta.nguoiDanhGia}');
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: scheme.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thông tin đề tài',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...lines.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(e),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.rows, required this.scheme});

  final List<TieuChiRow> rows;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fact_check_rounded, color: scheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Xem trước (${rows.length} tiêu chí)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...rows.take(8).map((r) => _PreviewRow(row: r)),
            if (rows.length > 8)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '… và ${rows.length - 8} tiêu chí khác',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.row});

  final TieuChiRow row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final diem = row.diem != null ? ' · ${row.diem!.toStringAsFixed(1)}đ' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 10),
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              '${row.tieuChi.isEmpty ? '(Chưa đặt tên)' : row.tieuChi}$diem',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.text,
    required this.scheme,
    required this.onCopy,
    required this.onExportCmt,
    required this.onExportTxt,
  });

  final String text;
  final ColorScheme scheme;
  final VoidCallback onCopy;
  final VoidCallback onExportCmt;
  final VoidCallback onExportTxt;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.article_outlined, color: scheme.tertiary),
                const SizedBox(width: 10),
                Text(
                  'Nhận xét sinh ra',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
                color: scheme.surface.withOpacity(0.85),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 220, maxHeight: 420),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    text.isEmpty
                        ? 'Chưa có nội dung. Hãy chọn file Excel hợp lệ.'
                        : text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                        ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: text.isEmpty ? null : onCopy,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Sao chép'),
                ),
                FilledButton.icon(
                  onPressed: text.isEmpty ? null : onExportCmt,
                  icon: const Icon(Icons.save_alt_rounded),
                  label: const Text('Xuất .cmt'),
                ),
                OutlinedButton.icon(
                  onPressed: text.isEmpty ? null : onExportTxt,
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Xuất .txt'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
