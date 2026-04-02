import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../services/gemini_service.dart';
import '../services/kakao_service.dart';

class RecommendScreen extends StatefulWidget {
  const RecommendScreen({super.key});

  @override
  State<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends State<RecommendScreen> {
  String? _weight;
  String? _cuisine;
  String? _price;
  bool _isLoading = false;
  Map<String, dynamic>? _cookResult;
  Map<String, dynamic>? _eatOutResult;
  List<Map<String, dynamic>> _restaurants = [];

  static const _weights = ['가벼운', '보통', '든든한'];
  static const _cuisines = ['한식', '일식', '중식', '양식', '분식', '동남아'];
  static const _prices = ['~8천', '~1.5만', '상관없음'];

  // 종류 → 카카오 검색 키워드 매핑
  static const _cuisineKeywords = {
    '한식': '한식',
    '일식': '일식',
    '중식': '중국집',
    '양식': '양식',
    '분식': '분식',
    '동남아': '태국 베트남 음식',
  };

  Future<List<String>> _getIngredients() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('ingredients');
    if (data == null) return [];
    return (jsonDecode(data) as List).map((e) => e['name'] as String).toList();
  }

  Future<Position> _getLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      if (result == LocationPermission.denied ||
          result == LocationPermission.deniedForever) {
        throw Exception('위치 권한이 필요합니다');
      }
    }
    return Geolocator.getCurrentPosition();
  }

  void _recommend() async {
    if (_weight == null || _cuisine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('무게감과 종류를 선택해주세요')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _cookResult = null;
      _eatOutResult = null;
      _restaurants = [];
    });

    try {
      // 1. 위치 + 재료 동시 가져오기
      final results = await Future.wait([
        _getLocation(),
        _getIngredients(),
      ]);
      final position = results[0] as Position;
      final ingredients = results[1] as List<String>;

      // 2. 카카오 음식점 검색
      final keyword = _cuisineKeywords[_cuisine] ?? _cuisine!;
      final restaurants = await KakaoService.searchRestaurants(
        lat: position.latitude,
        lng: position.longitude,
        keyword: keyword,
      );
      _restaurants = restaurants;

      // 3. Gemini 해먹기 + 사먹기 동시 호출
      final geminiResults = await Future.wait([
        GeminiService.recommendCook(
          ingredients: ingredients,
          weight: _weight!,
          cuisine: _cuisine!,
          price: _price,
        ),
        if (restaurants.isNotEmpty)
          GeminiService.recommendEatOut(
            weight: _weight!,
            cuisine: _cuisine!,
            price: _price,
            restaurants: restaurants,
          ),
      ]);

      setState(() {
        _cookResult = geminiResults[0];
        if (geminiResults.length > 1) _eatOutResult = geminiResults[1];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('추천 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎰 오늘 뭐먹지'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterSection('무게감', _weights, _weight,
                (v) => setState(() => _weight = v)),
            const SizedBox(height: 16),
            _buildFilterSection('종류', _cuisines, _cuisine,
                (v) => setState(() => _cuisine = v)),
            const SizedBox(height: 16),
            _buildFilterSection('가격대', _prices, _price,
                (v) => setState(() => _price = v)),
            const SizedBox(height: 24),

            // 추천받기 버튼
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _recommend,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome),
                label: Text(_isLoading ? 'AI가 고르는 중...' : '🤖 AI 추천받기'),
                style: FilledButton.styleFrom(
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 사먹기 결과
            if (_eatOutResult != null) _buildEatOutResult(),

            // 해먹기 결과
            if (_cookResult != null) ...[
              const SizedBox(height: 24),
              _buildCookResult(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEatOutResult() {
    final picks = _eatOutResult!['picks'] as List<dynamic>? ?? [];
    final comment = _eatOutResult!['comment'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (comment.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('🤖 $comment', style: const TextStyle(fontSize: 15)),
          ),
        const SizedBox(height: 16),
        const Text('🏪 사먹기',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...picks.map((p) {
          final pick = p as Map<String, dynamic>;
          final pickName = pick['name'] as String? ?? '';
          // 카카오 검색 결과에서 매칭
          final restaurant = _restaurants.cast<Map<String, dynamic>?>().firstWhere(
            (r) => r!['name'].toString().contains(pickName) ||
                pickName.contains(r['name'].toString()),
            orElse: () => null,
          );

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pickName,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(pick['reason'] ?? '',
                      style: TextStyle(color: Colors.grey.shade600)),
                  if (restaurant != null) ...[
                    const SizedBox(height: 8),
                    Text('📍 ${restaurant['address']} (${restaurant['distance']}m)',
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if ((restaurant['phone'] as String).isNotEmpty)
                          TextButton.icon(
                            onPressed: () => launchUrl(
                                Uri.parse('tel:${restaurant['phone']}')),
                            icon: const Icon(Icons.phone, size: 16),
                            label: const Text('전화'),
                          ),
                        TextButton.icon(
                          onPressed: () =>
                              launchUrl(Uri.parse(restaurant['url'])),
                          icon: const Icon(Icons.map, size: 16),
                          label: const Text('지도보기'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCookResult() {
    final recipes = _cookResult!['recipes'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('🍳 해먹기',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...recipes.map((r) => _buildRecipeCard(r as Map<String, dynamic>)),
      ],
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(recipe['name'] ?? '',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(recipe['reason'] ?? '',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            if (recipe['ingredients'] != null)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: (recipe['ingredients'] as List<dynamic>).map((i) {
                  return Chip(
                    label:
                        Text(i.toString(), style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            const SizedBox(height: 8),
            if (recipe['recipe'] != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(recipe['recipe'],
                    style: const TextStyle(fontSize: 13, height: 1.5)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(String title, List<String> options,
      String? selected, ValueChanged<String> onSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            return ChoiceChip(
              label: Text(option),
              selected: selected == option,
              onSelected: (_) => onSelected(option),
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
            );
          }).toList(),
        ),
      ],
    );
  }
}
