import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static final _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static Future<Map<String, dynamic>> _call(String prompt) async {
    for (int retry = 0; retry < 3; retry++) {
      debugPrint('[Gemini] 호출 시도 ${retry + 1}/3');
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {'parts': [{'text': prompt}]}
          ],
          'generationConfig': {'temperature': 0.8, 'maxOutputTokens': 4000},
        }),
      );

      debugPrint('[Gemini] 응답 코드: ${response.statusCode}');

      if (response.statusCode == 429) {
        debugPrint('[Gemini] 429 한도 초과, ${5 * (retry + 1)}초 대기');
        await Future.delayed(Duration(seconds: 5 * (retry + 1)));
        continue;
      }

      if (response.statusCode != 200) {
        debugPrint('[Gemini] 에러 응답: ${response.body}');
        throw Exception('Gemini API 오류: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
      debugPrint('[Gemini] 응답 텍스트: ${text.substring(0, text.length > 100 ? 100 : text.length)}...');
      try {
        var cleaned = text.trim();
        // ```json ... ``` 마크다운 블록 제거
        if (cleaned.startsWith('```')) {
          cleaned = cleaned.substring(cleaned.indexOf('\n') + 1);
          if (cleaned.endsWith('```')) {
            cleaned = cleaned.substring(0, cleaned.lastIndexOf('```'));
          }
        }
        cleaned = cleaned.trim();
        final jsonStr = cleaned.substring(cleaned.indexOf('{'), cleaned.lastIndexOf('}') + 1);
        return jsonDecode(jsonStr) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('[Gemini] JSON 파싱 실패: $e / 원본: $text');
        rethrow;
      }
    }
    debugPrint('[Gemini] 3회 재시도 모두 실패 (429)');
    throw Exception('AI 서버가 바빠요. 잠시 후 다시 시도해주세요');
  }

  /// 냉장고 탭 전용: 해먹기만 추천
  static Future<Map<String, dynamic>> recommendCook({
    required List<String> ingredients,
    required String weight,
    required String cuisine,
    String? price,
  }) async {
    final ingredientText = ingredients.isEmpty
        ? '등록된 재료 없음 (일반적인 재료 기준으로 추천)'
        : ingredients.join(', ');

    return _call('''
당신은 요리 추천 전문가입니다. 친근하게 추천해주세요.

[조건]
${weight != '상관없음' ? '- 무게감: $weight' : ''}
${cuisine != '상관없음' ? '- 종류: $cuisine' : '- 종류: 아무거나 OK'}
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
}''');
  }

  /// 사먹기 추천 (주변 음식점 기반)
  static Future<Map<String, dynamic>> recommendEatOut({
    required String weight,
    required String cuisine,
    String? price,
    required List<Map<String, dynamic>> restaurants,
    List<String> excludeNames = const [],
  }) async {
    final restaurantText = restaurants.asMap().entries.map((e) {
      final r = e.value;
      return '${e.key + 1}. ${r['name']} (${r['distance']}m) - ${r['category']}';
    }).join('\n');

    final excludeText = excludeNames.isNotEmpty
        ? '\n[제외] 다음 음식점은 이미 추천했으니 반드시 제외하세요: ${excludeNames.join(', ')}'
        : '';

    return _call('''
당신은 점심 메뉴 추천 전문가입니다. 친근하게 추천해주세요.

[조건]
- 무게감: $weight
- 종류: $cuisine
${price != null ? '- 가격대: $price' : ''}

[내 주변 음식점]
$restaurantText
$excludeText

위 음식점 중 조건에 가장 맞는 곳 최대 2개를 골라 추천해주세요.
반드시 아래 JSON 형식으로만 응답하세요. 다른 텍스트 없이 JSON만 출력하세요.

{
  "comment": "한 줄 인사말",
  "picks": [
    {
      "name": "음식점명 (위 목록에 있는 이름 그대로)",
      "reason": "추천 이유 한 줄"
    }
  ]
}''');
  }
}
