import '../models/de_tai_meta.dart';
import '../models/tieu_chi_row.dart';

class NhanXetGenerator {
  String buildFullReport({
    required DeTaiMeta meta,
    required List<TieuChiRow> rows,
    DateTime? generatedAt,
  }) {
    final now = generatedAt ?? DateTime.now();
    final buf = StringBuffer();
    buf.writeln('NHẬN XÉT ĐỀ TÀI');
    buf.writeln('—'.padRight(48, '—'));
    if (meta.tenDeTai.isNotEmpty) {
      buf.writeln('Đề tài: ${meta.tenDeTai}');
    }
    if (meta.tenSinhVien.isNotEmpty) {
      buf.writeln('Sinh viên: ${meta.tenSinhVien}');
    }
    if (meta.maLop.isNotEmpty) {
      buf.writeln('Lớp/Mã: ${meta.maLop}');
    }
    if (meta.nguoiDanhGia.isNotEmpty) {
      buf.writeln('Người đánh giá: ${meta.nguoiDanhGia}');
    }
    buf.writeln(
      'Thời điểm tạo: ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
    );
    buf.writeln();
    buf.writeln('I. TỔNG QUAN');
    buf.writeln(_moDau(meta, rows));
    buf.writeln();
    buf.writeln('II. NHẬN XÉT THEO TIÊU CHÍ');
    for (var i = 0; i < rows.length; i++) {
      buf.writeln();
      buf.writeln('${i + 1}. ${_tieuChiTitle(rows[i].tieuChi)}');
      buf.writeln(_forRow(rows[i]));
    }
    buf.writeln();
    buf.writeln('III. KẾT LUẬN');
    buf.writeln(_ketLuan(rows));
    return buf.toString().trim();
  }

  String _moDau(DeTaiMeta meta, List<TieuChiRow> rows) {
    final parts = <String>[];
    if (meta.tenDeTai.isNotEmpty) {
      parts.add('Đề tài "${meta.tenDeTai}" được trình bày với ${rows.length} tiêu chí đánh giá.');
    } else {
      parts.add('Bài làm được đối chiếu với ${rows.length} tiêu chí trong bảng đánh giá.');
    }
    final avg = _averageScore(rows);
    if (avg != null) {
      parts.add('Điểm trung bình các tiêu chí có chấm điểm: ${avg.toStringAsFixed(1)}/10.');
    }
    parts.add(
      'Các nhận xét chi tiết dưới đây căn cứ trên nội dung và điểm số (nếu có) trong file Excel.',
    );
    return parts.join(' ');
  }

  double? _averageScore(List<TieuChiRow> rows) {
    final ds = rows.where((e) => e.diem != null).map((e) => e.diem!).toList();
    if (ds.isEmpty) return null;
    return ds.reduce((a, b) => a + b) / ds.length;
  }

  String _tieuChiTitle(String raw) {
    final t = raw.trim();
    return t.isEmpty ? 'Tiêu chí' : t;
  }

  String _forRow(TieuChiRow r) {
    final tc = _tieuChiTitle(r.tieuChi);
    final lines = <String>[];

    if (r.diem != null) {
      lines.add(_sentenceDiem(tc, r.diem!));
    }
    lines.add(_sentenceNoiDung(tc, r.noiDung));
    if (r.ghiChu.isNotEmpty) {
      lines.add('Ghi chú từ bảng đánh giá: ${r.ghiChu}');
    }
    lines.add(_goiYTheoTuKhoa(tc, r.noiDung, r.diem));
    return lines.where((e) => e.isNotEmpty).join('\n');
  }

  String _sentenceDiem(String tieuChi, double d) {
    final cap = _capDo(d);
    return 'Về "$tieuChi", mức đánh giá định lượng: ${d.toStringAsFixed(1)}/10 — $cap.';
  }

  String _capDo(double d) {
    if (d >= 9) return 'xuất sắc, đáp ứng tốt yêu cầu';
    if (d >= 8) return 'rất tốt, hoàn thành vững các yêu cầu';
    if (d >= 7) return 'tốt, đạt yêu cầu chính';
    if (d >= 5.5) return 'khá, còn một số điểm cần hoàn thiện';
    if (d >= 4) return 'trung bình, cần bổ sung và chỉnh sửa';
    return 'chưa đạt, cần làm lại phần liên quan';
  }

  String _sentenceNoiDung(String tieuChi, String noiDung) {
    final nd = noiDung.trim();
    if (nd.isEmpty) {
      return 'Phần mô tả/minh chứng cho "$tieuChi" còn sơ sài hoặc chưa có trong bảng — nên bổ sung tài liệu, hình ảnh hoặc liên kết demo rõ ràng hơn.';
    }
    final short = nd.length > 320 ? '${nd.substring(0, 320)}…' : nd;
    return 'Nội dung ghi nhận: $short';
  }

  String _goiYTheoTuKhoa(String tieuChi, String noiDung, double? diem) {
    final blob = '${_normalize(tieuChi)} ${_normalize(noiDung)}';
    final hints = <String>[];

    if (blob.contains('chuc nang') || blob.contains('function')) {
      hints.add(
        'Gợi ý: kiểm tra lại luồng nghiệp vụ chính, xử lý lỗi và các trường hợp biên.',
      );
    }
    if (blob.contains('ui') ||
        blob.contains('giao dien') ||
        blob.contains('ux') ||
        blob.contains('interface')) {
      hints.add(
        'Gợi ý: thống nhất bố cục, khoảng cách, màu sắc và trạng thái tải/lỗi trên giao diện.',
      );
    }
    if (blob.contains('tai lieu') ||
        blob.contains('bao cao') ||
        blob.contains('readme') ||
        blob.contains('document')) {
      hints.add(
        'Gợi ý: bổ sung sơ đồ kiến trúc, hướng dẫn cài đặt/chạy và mô tả API nếu có.',
      );
    }
    if (blob.contains('demo') || blob.contains('video') || blob.contains('thuyet minh')) {
      hints.add('Gợi ý: demo nên thể hiện rõ tính năng nổi bật và kịch bản kiểm thử ngắn.');
    }
    if (blob.contains('bao mat') || blob.contains('security')) {
      hints.add('Gợi ý: nêu rõ xác thực, phân quyền và các rủi ro đã xử lý.');
    }
    if (blob.contains('csdl') ||
        blob.contains('database') ||
        blob.contains('du lieu')) {
      hints.add('Gợi ý: mô tả mô hình dữ liệu, chỉ mục và sao lưu/phục hồi nếu có.');
    }

    if (hints.isEmpty) {
      if (diem != null && diem < 6) {
        return 'Gợi ý: rà soát lại yêu cầu của tiêu chí này và bổ sung minh chứng cụ thể.';
      }
      return '';
    }
    return hints.take(2).join('\n');
  }

  String _ketLuan(List<TieuChiRow> rows) {
    final avg = _averageScore(rows);
    if (avg == null) {
      return 'Nhìn chung đề tài thể hiện đầy đủ các nội dung theo bảng tiêu chí. '
          'Đề nghị sinh viên bổ sung điểm số/đánh giá định lượng (nếu quy định) để thuận tiện xếp loại.';
    }
    if (avg >= 8) {
      return 'Kết luận: đạt tốt trên các tiêu chí có chấm điểm. Có thể hoàn thiện thêm phần trình bày và tài liệu kèm theo để tăng tính thuyết phục.';
    }
    if (avg >= 6.5) {
      return 'Kết luận: đạt yêu cầu cơ bản. Một số tiêu chí cần chỉnh sửa theo gợi ý chi tiết phía trên trước khi nộp bản cuối.';
    }
    return 'Kết luận: cần chỉnh sửa bổ sung theo các nhận xét chi tiết; ưu tiên các tiêu chí có điểm thấp và thiếu mô tả minh chứng.';
  }

  String _normalize(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
