/// Tiện ích so khớp mờ chuỗi văn bản bằng thuật toán Levenshtein Distance.
/// Hỗ trợ chuẩn hóa tiếng Việt trước khi so sánh để tăng độ chính xác.
class FuzzyMatcher {
  // Bảng chuyển đổi ký tự tiếng Việt có dấu sang không dấu
  static const _viMap = {
    'á': 'a', 'à': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
    'ă': 'a', 'ắ': 'a', 'ằ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
    'â': 'a', 'ấ': 'a', 'ầ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
    'đ': 'd',
    'é': 'e', 'è': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
    'ê': 'e', 'ế': 'e', 'ề': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
    'í': 'i', 'ì': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
    'ó': 'o', 'ò': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
    'ô': 'o', 'ố': 'o', 'ồ': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
    'ơ': 'o', 'ớ': 'o', 'ờ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
    'ú': 'u', 'ù': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
    'ư': 'u', 'ứ': 'u', 'ừ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
    'ý': 'y', 'ỳ': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
  };

  /// Chuẩn hóa chuỗi: loại dấu tiếng Việt, chuyển chữ thường,
  /// gộp khoảng trắng thừa.
  static String normalize(String s) {
    final buf = StringBuffer();
    for (final ch in s.toLowerCase().runes) {
      final c = String.fromCharCode(ch);
      buf.write(_viMap[c] ?? c);
    }
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Tính khoảng cách Levenshtein giữa hai chuỗi đã chuẩn hóa.
  static int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    final sLen = s.length;
    final tLen = t.length;

    // Dùng 2 mảng 1D thay vì ma trận 2D để tiết kiệm bộ nhớ
    var prev = List<int>.generate(tLen + 1, (i) => i);
    var curr = List<int>.filled(tLen + 1, 0);

    for (var i = 1; i <= sLen; i++) {
      curr[0] = i;
      for (var j = 1; j <= tLen; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        curr[j] = [
          prev[j] + 1,       // xóa
          curr[j - 1] + 1,   // chèn
          prev[j - 1] + cost // thay thế
        ].reduce((a, b) => a < b ? a : b);
      }
      // Hoán đổi mảng
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }

    return prev[tLen];
  }

  /// Tính độ tương đồng giữa hai chuỗi từ 0.0 đến 1.0 (1.0 = giống hoàn toàn).
  /// Chuẩn hóa tiếng Việt trước khi so sánh.
  static double getSimilarity(String s1, String s2) {
    final n1 = normalize(s1);
    final n2 = normalize(s2);

    if (n1.isEmpty && n2.isEmpty) return 1.0;
    if (n1.isEmpty || n2.isEmpty) return 0.0;
    if (n1 == n2) return 1.0;

    final distance = _levenshtein(n1, n2);
    final maxLen = n1.length > n2.length ? n1.length : n2.length;
    return 1.0 - (distance / maxLen);
  }

  /// Trả về true nếu hai chuỗi tương đồng >= ngưỡng (mặc định 90%).
  static bool isMatch(String s1, String s2, {double threshold = 0.9}) {
    return getSimilarity(s1, s2) >= threshold;
  }

  /// Tính phần trăm tương đồng (0–100).
  static int getSimilarityPercent(String s1, String s2) {
    return (getSimilarity(s1, s2) * 100).round();
  }
}
