import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 냉장고 해먹기 추천 결과를 캐싱하는 서비스
class CookCacheService {
  static const _cacheKey = 'cook_cache';
  static const _ingredientsHashKey = 'cook_cache_hash';

  /// 해먹기 결과 저장 (재료 해시와 함께)
  static Future<void> save(Map<String, dynamic> result, List<String> ingredients) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(result));
    await prefs.setString(_ingredientsHashKey, _hash(ingredients));
  }

  /// 저장된 해먹기 결과 가져오기 (재료가 바뀌었으면 null)
  static Future<Map<String, dynamic>?> get() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_cacheKey);
    if (data == null) return null;

    // 현재 재료와 캐시 시점 재료 비교
    final currentIngredients = await _getCurrentIngredients(prefs);
    final cachedHash = prefs.getString(_ingredientsHashKey) ?? '';
    if (_hash(currentIngredients) != cachedHash) return null;

    return jsonDecode(data) as Map<String, dynamic>;
  }

  static Future<List<String>> _getCurrentIngredients(SharedPreferences prefs) async {
    final data = prefs.getString('ingredients');
    if (data == null) return [];
    return (jsonDecode(data) as List).map((e) => e['name'] as String).toList();
  }

  /// 재료 목록을 정렬 후 해시 (순서 무관하게 비교)
  static String _hash(List<String> ingredients) {
    final sorted = List<String>.from(ingredients)..sort();
    return sorted.join(',');
  }
}
