import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class KakaoService {
  static final _apiKey = dotenv.env['KAKAO_REST_API_KEY'] ?? '';

  /// 주변 음식점 검색
  static Future<List<Map<String, dynamic>>> searchRestaurants({
    required double lat,
    required double lng,
    required String keyword,
    int radius = 2000,
  }) async {
    final url = Uri.https('dapi.kakao.com', '/v2/local/search/keyword.json', {
      'query': '$keyword 맛집',
      'x': lng.toString(),
      'y': lat.toString(),
      'radius': radius.toString(),
      'category_group_code': 'FD6',
      'size': '10',
      'sort': 'distance',
    });

    final response = await http.get(url, headers: {
      'Authorization': 'KakaoAK $_apiKey',
    });

    if (response.statusCode != 200) {
      final body = response.body;
      throw Exception('카카오 API 오류 (${response.statusCode}): $body');
    }

    final data = jsonDecode(response.body);
    final documents = data['documents'] as List<dynamic>;

    return documents.map((d) => {
      'name': (d['place_name'] ?? '') as String,
      'category': (d['category_name'] ?? '') as String,
      'address': (d['road_address_name'] ?? d['address_name'] ?? '') as String,
      'distance': (d['distance'] ?? '0') as String,
      'phone': (d['phone'] ?? '') as String,
      'url': (d['place_url'] ?? '') as String,
    }).toList();
  }
}
