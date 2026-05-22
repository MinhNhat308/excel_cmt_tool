import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/project_provider.dart';
import '../theme/app_theme.dart';
import 'import_xlsx_screen.dart';
import 'project_list_screen.dart';
import 'cmt_viewer_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isLoading = false;

  Future<void> _openFgFile() async {
    setState(() => _isLoading = true);

    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['fg'],
      );
      if (r == null || r.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }
      final path = r.files.single.path;
      if (path == null) {
        setState(() => _isLoading = false);
        return;
      }

      final success = ref.read(projectListProvider.notifier).loadFromFgFile(path);
      setState(() => _isLoading = false);

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tải thành công tệp dự án (.fg)!')),
        );
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (context) => const ProjectListScreen(),
          ),
        );
      } else {
        final error = ref.read(projectListProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Có lỗi xảy ra khi mở tệp .fg.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi mở tệp: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('FUGE Tool — Quản lý Đánh giá Khóa luận'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: DecoratedBox(
        decoration: AppTheme.pageGradient(context),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo / Header Section
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: scheme.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.verified_user_rounded,
                                size: 80,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'HỆ THỐNG ĐÁNH GIÁ FUGE',
                              style: t.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: scheme.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Công cụ hỗ trợ Giảng viên tổng hợp, nhập điểm, và xuất/đọc phiếu nhận xét khóa luận tốt nghiệp bảo mật .cmt',
                              style: t.bodyLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),

                        // Actions Grid (Centered on Desktop)
                        Align(
                          alignment: Alignment.center,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 960),
                            child: GridView.count(
                              crossAxisCount: 3,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 24,
                              mainAxisSpacing: 24,
                              childAspectRatio: 0.95,
                              children: [
                                // Action 1: Import XLSX -> Create .fg
                                _HomeActionCard(
                                  icon: Icons.add_moderator_rounded,
                                  title: 'Import XLSX → Tạo .fg',
                                  description: 'Tải lên bảng khảo sát Excel để bắt đầu tạo tệp danh sách đề tài và nhóm bảo vệ tốt nghiệp mới.',
                                  color: scheme.primary,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (context) => const ImportXlsxScreen(),
                                      ),
                                    );
                                  },
                                  scheme: scheme,
                                  t: t,
                                ),

                                // Action 2: Open .fg project
                                _HomeActionCard(
                                  icon: Icons.folder_shared_rounded,
                                  title: 'Mở file dự án .fg',
                                  description: 'Tiếp tục chỉnh sửa bảng điểm, đồng bộ khảo sát sinh viên, điền nhận xét và xuất các file đánh giá.',
                                  color: scheme.secondary,
                                  onTap: _openFgFile,
                                  scheme: scheme,
                                  t: t,
                                ),

                                // Action 3: Open .cmt comment
                                _HomeActionCard(
                                  icon: Icons.lock_open_rounded,
                                  title: 'Mở file nhận xét .cmt',
                                  description: 'Giải mã tệp nhị phân .cmt để đọc trực quan phiếu đánh giá khóa luận tốt nghiệp của từng đề tài.',
                                  color: scheme.tertiary,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (context) => const CmtViewerScreen(),
                                      ),
                                    );
                                  },
                                  scheme: scheme,
                                  t: t,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 60),

                        // Footer versioning info
                        Text(
                          'Phiên bản 1.0.0 — Phát triển bởi Antigravity',
                          style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant.withOpacity(0.5)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
    required this.scheme,
    required this.t,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;
  final ColorScheme scheme;
  final TextTheme t;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: scheme.shadow.withOpacity(0.05),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: t.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: scheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  description,
                  style: t.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
