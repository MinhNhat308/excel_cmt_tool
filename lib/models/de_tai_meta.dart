class DeTaiMeta {
  const DeTaiMeta({
    this.tenDeTai = '',
    this.tenSinhVien = '',
    this.maLop = '',
    this.nguoiDanhGia = '',
  });

  final String tenDeTai;
  final String tenSinhVien;
  final String maLop;
  final String nguoiDanhGia;

  bool get hasAny =>
      tenDeTai.isNotEmpty ||
      tenSinhVien.isNotEmpty ||
      maLop.isNotEmpty ||
      nguoiDanhGia.isNotEmpty;
}
