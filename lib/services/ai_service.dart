import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  static const String _prefKey = 'gemini_api_key';
  // Default API Key provided by user
  static String get _defaultApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  
  String? _apiKey;

  static final AIService instance = AIService._internal();
  AIService._internal();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_prefKey) ?? _defaultApiKey;
  }

  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, key.trim());
    _apiKey = key.trim();
  }

  String get currentApiKey => _apiKey ?? _defaultApiKey;

  Future<String> generateEvaluation(String fieldName, String keywords) async {
    if (keywords.trim().isEmpty) return '';

    final key = _apiKey ?? _defaultApiKey;
    if (key.isEmpty) {
      throw Exception('Vui lòng thiết lập API Key trong cài đặt.');
    }

    final model = GenerativeModel(
      model: 'gemini-3.5-flash',
      apiKey: key,
      generationConfig: GenerationConfig(
        temperature: 1.2, // Cao để mỗi lần bấm sinh ra một văn phong hơi khác nhau
      ),
    );

    final prompt = '''
Bạn là một Giảng viên đại học đang viết nhận xét chấm điểm khóa luận tốt nghiệp cho nhóm sinh viên ngành CNTT.
Hãy viết một đoạn văn ngắn gọn, mang tính học thuật cao, chuyên nghiệp dựa trên các từ khóa nháp dưới đây.
Đoạn văn này sẽ được điền thẳng vào phần: "$fieldName".
Từ khóa nháp của giảng viên: "$keywords"

Yêu cầu:
- KHÔNG thêm các từ ngữ xưng hô hay mở bài như "Dưới đây là", "Đoạn văn của bạn".
- Đi thẳng vào nội dung nhận xét.
- Giữ độ dài từ 1 đến 4 câu tùy độ phức tạp của từ khóa.
- Viết câu hoàn chỉnh, đúng ngữ pháp, dùng từ ngữ chuyên ngành công nghệ thông tin và học thuật.
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text?.replaceAll(RegExp(r'^"|"$'), '').trim() ?? '';
    } catch (e) {
      throw Exception('Lỗi gọi AI: $e');
    }
  }
}
