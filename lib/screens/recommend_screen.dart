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

  static const _cuisineKeywords = {
    '한식': '한식', '일식': '일식', '중식': '중국집',
    '양식': '양식', '분식': '분식', '동남아': '태국 베트남 음식',
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
        SnackBar(
          content: const Text('무게감과 종류를 선택해주세요'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
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
      final results = await Future.wait([_getLocation(), _getIngredients()]);
      final position = results[0] as Position;
      final ingredients = results[1] as List<String>;

      final keyword = _cuisineKeywords[_cuisine] ?? _cuisine!;
      final restaurants = await KakaoService.searchRestaurants(
        lat: position.latitude, lng: position.longitude, keyword: keyword,
      );
      _restaurants = restaurants;

      final geminiResults = await Future.wait([
        GeminiService.recommendCook(
          ingredients: ingredients, weight: _weight!, cuisine: _cuisine!, price: _price,
        ),
        if (restaurants.isNotEmpty)
          GeminiService.recommendEatOut(
            weight: _weight!, cuisine: _cuisine!, price: _price, restaurants: restaurants,
          ),
      ]);

      setState(() {
        _cookResult = geminiResults[0];
        if (geminiResults.length > 1) _eatOutResult = geminiResults[1];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('추천 실패: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 그라데이션 헤더
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🎰 오늘 뭐먹지',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('AI가 딱 맞는 메뉴를 골라줄게요',
                      style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.85))),
                ],
              ),
            ),
          ),

          // 필터 + 결과
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildFilterCard('무게감', _weights, _weight,
                    (v) => setState(() => _weight = v)),
                const SizedBox(height: 12),
                _buildFilterCard('종류', _cuisines, _cuisine,
                    (v) => setState(() => _cuisine = v)),
                const SizedBox(height: 12),
                _buildFilterCard('가격대', _prices, _price,
                    (v) => setState(() => _price = v)),
                const SizedBox(height: 20),

                // 추천 버튼
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: _isLoading
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)]),
                    borderRadius: BorderRadius.circular(16),
                    color: _isLoading ? Colors.grey.shade300 : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _isLoading ? null : _recommend,
                      child: Center(
                        child: _isLoading
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white)),
                                  SizedBox(width: 12),
                                  Text('AI가 고르는 중...',
                                      style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                                ],
                              )
                            : const Text('🤖 AI 추천받기',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 사먹기 결과
                if (_eatOutResult != null) _buildEatOutSection(),

                // 해먹기 결과
                if (_cookResult != null) ...[
                  const SizedBox(height: 20),
                  _buildCookSection(),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard(String title, List<String> options, String? selected,
      ValueChanged<String> onSelected) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF636E72))),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = selected == option;
              return GestureDetector(
                onTap: () => onSelected(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)])
                        : null,
                    color: isSelected ? null : const Color(0xFFF1F2F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(option,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF636E72),
                      )),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEatOutSection() {
    final picks = _eatOutResult!['picks'] as List<dynamic>? ?? [];
    final comment = _eatOutResult!['comment'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (comment.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF6B35).withValues(alpha: 0.08),
                  const Color(0xFFFF8E53).withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text('🤖 $comment',
                style: const TextStyle(fontSize: 15, height: 1.4)),
          ),
        const SizedBox(height: 16),
        const Text('🏪 사먹기',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ...picks.map((p) {
          final pick = p as Map<String, dynamic>;
          final pickName = pick['name'] as String? ?? '';
          final restaurant =
              _restaurants.cast<Map<String, dynamic>?>().firstWhere(
                    (r) =>
                        r!['name'].toString().contains(pickName) ||
                        pickName.contains(r['name'].toString()),
                    orElse: () => null,
                  );

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pickName,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(pick['reason'] ?? '',
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF636E72), height: 1.4)),
                if (restaurant != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 14, color: Color(0xFFFF6B35)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                            '${restaurant['address']} · ${restaurant['distance']}m',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF636E72))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if ((restaurant['phone'] as String).isNotEmpty)
                        _buildActionButton(Icons.phone, '전화',
                            () => launchUrl(Uri.parse('tel:${restaurant['phone']}'))),
                      const SizedBox(width: 8),
                      _buildActionButton(Icons.map, '지도보기',
                          () => launchUrl(Uri.parse(restaurant['url']))),
                    ],
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFFFF6B35)),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF6B35))),
          ],
        ),
      ),
    );
  }

  Widget _buildCookSection() {
    final recipes = _cookResult!['recipes'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('🍳 해먹기',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ...recipes.map((r) => _buildRecipeCard(r as Map<String, dynamic>)),
      ],
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(recipe['name'] ?? '',
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(recipe['reason'] ?? '',
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF636E72), height: 1.4)),
          const SizedBox(height: 10),
          if (recipe['ingredients'] != null)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: (recipe['ingredients'] as List<dynamic>).map((i) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F2F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(i.toString(),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF636E72))),
                );
              }).toList(),
            ),
          if (recipe['recipe'] != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('👨‍🍳 ${recipe['recipe']}',
                  style: const TextStyle(
                      fontSize: 13, height: 1.6, color: Color(0xFF5D4037))),
            ),
          ],
        ],
      ),
    );
  }
}
