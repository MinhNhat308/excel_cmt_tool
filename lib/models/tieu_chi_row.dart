class TieuChiRow {
  const TieuChiRow({
    required this.tieuChi,
    required this.noiDung,
    this.diem,
    this.ghiChu = '',
  });

  final String tieuChi;
  final String noiDung;
  final double? diem;
  final String ghiChu;

  bool get isEmpty =>
      tieuChi.isEmpty && noiDung.isEmpty && ghiChu.isEmpty && diem == null;
}
