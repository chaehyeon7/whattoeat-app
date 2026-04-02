import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static final _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  static Future<Map<String, dynamic>> recommendCook({
    required List<String> ingredients,
    required String weight,
    required String cuisine,
    String? price,
  }) async {
    final ingredientText = ingredients.isEmpty
        ? '등록된 재료 없음 (일반적인 재료 기준으로 추천)'
        : ingredients.join(', ');

    final prompt = '''
당신은 요리 추천 전문가입니다. 친근하게 추천해주세요.

[조건]
- 무게감: $weight
- 종류: $cuisine
${price != null ? '- 가격대: $price' : ''}

[냉장고 재료]
$ingredientText

위 재료로 만들 수 있는 요리 2~3개를 추천해주세요.
반드시 아래 JSON 형식으로만 응답하세요. 다른 텍스트 없이 JSON만 출력하세요.

{
  "comment": "한 줄 인사말",
  "recipes": [
    {
      "name": "요리명",
      "reason": "추천 이유 한 줄",
      "ingredients": ["필요 재료1", "필요 재료2"],
      "recipe": "간단 레시피 3줄 이내"
    }
  ]
}''';

    final response = await http.post(
      Uri.parse('$_baseUrl?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.8,
          'maxOutputTokens': 1024,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API 오류: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final text = data['candidates'][0]['content']['parts'][0]['text'] as String;

    // JSON 블록 추출 (```json ... ``` 또는 순수 JSON)
    final jsonStr = text.contains('{')
        ? text.substring(text.indexOf('{'), text.lastIndexOf('}') + 1)
        : text;

    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }
}
