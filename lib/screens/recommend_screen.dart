import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/gemini_service.dart';
import '../services/kakao_service.dart';
import '../services/cook_cache_service.dart';
import 'recipe_detail_screen.dart';

class RecommendScreen extends StatefulWidget {
  const RecommendScreen({super.key});

  @override
  State<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends State<RecommendScreen> {
  String? _weight;
  String? _cuisine;
  String? _price;
  double _radiusKm = 1.0;
  bool _isLoading = false;
  bool _hasResult = false;
  bool _hasError = false;
  Map<String, dynamic>? _eatOutResult;
  Map<String, dynamic>? _cookResult;
  List<Map<String, dynamic>> _restaurants = [];
  List<String> _previousPicks = [];
  final _scrollController = ScrollController();

  static const _weights = ['가벼운', '보통', '든든한'];
  static const _cuisines = ['한식', '일식', '중식', '양식', '분식', '동남아'];
  static const _prices = ['~8천', '~1.5만', '상관없음'];

  static const _cuisineKeywords = {
    '한식': '한식', '일식': '일식', '중식': '중국집',
    '양식': '양식', '분식': '분식', '동남아': '태국 베트남 음식',
  };

  Future<Position> _getLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      if (result == LocationPermission.denied) {
        throw Exception('위치 권한이 필요해요. 설정에서 허용해주세요!');
      }
      if (result == LocationPermission.deniedForever) {
        throw Exception('위치 권한이 차단되어 있어요. 설정 > 앱 > 뭐먹지 > 위치 에서 허용해주세요!');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('위치 권한이 차단되어 있어요. 설정 > 앱 > 뭐먹지 > 위치 에서 허용해주세요!');
    }
    return Geolocator.getCurrentPosition();
  }

  void _scrollToResult() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showRadiusSetting() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text('📍 검색 반경  ${_radiusKm.toStringAsFixed(1)}km',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: const Color(0xFFFF6B35),
                  inactiveTrackColor: const Color(0xFFF1F2F6),
                  thumbColor: const Color(0xFFFF6B35),
                  overlayColor: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                  valueIndicatorColor: const Color(0xFFFF6B35),
                  showValueIndicator: ShowValueIndicator.always,
                ),
                child: Slider(
                  value: _radiusKm,
                  min: 0.5,
                  max: 5.0,
                  divisions: 9,
                  label: '${_radiusKm.toStringAsFixed(1)}km',
                  onChanged: (v) {
                    setSheetState(() {});
                    setState(() => _radiusKm = v);
                  },
                ),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0.5km', style: TextStyle(fontSize: 12, color: Color(0xFFB2BEC3))),
                  Text('5.0km', style: TextStyle(fontSize: 12, color: Color(0xFFB2BEC3))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _randomRecommend() {
    final rng = Random();
    setState(() {
      _weight = _weights[rng.nextInt(_weights.length)];
      _cuisine = _cuisines[rng.nextInt(_cuisines.length)];
      _price = _prices[rng.nextInt(_prices.length)];
    });
    _recommend();
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
      _hasResult = false;
      _hasError = false;
      _eatOutResult = null;
      _cookResult = null;
      _restaurants = [];
    });

    // 필터가 바뀌었으면 제외 목록 초기화 (다시 추천만 누른 거면 유지)

    try {
      final position = await _getLocation();

      // 카카오 음식점 검색
      final keyword = _cuisineKeywords[_cuisine] ?? _cuisine!;
      final restaurants = await KakaoService.searchRestaurants(
        lat: position.latitude, lng: position.longitude, keyword: keyword,
        radius: (_radiusKm * 1000).toInt(),
      );
      _restaurants = restaurants;

      if (restaurants.isEmpty) {
        final cachedCook = await CookCacheService.get();
        setState(() {
          _eatOutResult = {'comment': '근처에 ${_cuisine} 음식점을 못 찾았어요 😢', 'picks': []};
          _cookResult = cachedCook;
          _hasResult = true;
        });
        _scrollToResult();
        return;
      }

      // Gemini 사먹기만 호출 + 캐시된 해먹기 가져오기
      final geminiResult = await GeminiService.recommendEatOut(
        weight: _weight!,
        cuisine: _cuisine!,
        price: _price,
        restaurants: restaurants,
        excludeNames: _previousPicks,
      );

      // 이번 추천 이름을 누적
      final picks = geminiResult['picks'] as List<dynamic>? ?? [];
      _previousPicks.addAll(picks.map((p) => (p as Map<String, dynamic>)['name'] as String? ?? ''));

      final cachedCook = await CookCacheService.get();

      setState(() {
        _eatOutResult = geminiResult;
        _cookResult = cachedCook;
        _hasResult = true;
      });
      _scrollToResult();
    } catch (e) {
      debugPrint('[Recommend] 추천 실패: $e');
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 헤더
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('🎰 오늘 뭐먹지',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                      GestureDetector(
                        onTap: _showRadiusSetting,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.near_me, size: 16, color: Colors.white),
                              const SizedBox(width: 4),
                              Text('${_radiusKm.toStringAsFixed(1)}km',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('AI가 딱 맞는 메뉴를 골라줄게요',
                      style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.85))),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 필터
                _buildFilterCard('무게감', _weights, _weight, (v) => setState(() => _weight = v)),
                const SizedBox(height: 12),
                _buildFilterCard('종류', _cuisines, _cuisine, (v) => setState(() => _cuisine = v)),
                const SizedBox(height: 12),
                _buildFilterCard('가격대', _prices, _price, (v) => setState(() => _price = v)),
                const SizedBox(height: 20),

                // 추천 버튼
                _buildRecommendButton(),
                const SizedBox(height: 10),
                // 아몰랑 버튼
                GestureDetector(
                  onTap: _isLoading ? null : _randomRecommend,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: _isLoading ? null : const LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)]),
                      color: _isLoading ? Colors.grey.shade300 : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text('🎲 아몰랑!', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 결과
                // 에러 시 재시도
                if (_hasError) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      children: [
                        const Text('😢', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        const Text('추천을 가져오지 못했어요', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        const Text('인터넷 연결을 확인하고 다시 시도해주세요', style: TextStyle(fontSize: 14, color: Color(0xFF636E72))),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _recommend,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)]),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text('🔄 다시 시도', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_hasResult) ...[
                  // 사먹기
                  if (_eatOutResult != null) _buildEatOutSection(),

                  // 다시 고르기 버튼
                  const SizedBox(height: 16),
                  _buildRetryButton(),

                  // 해먹기
                  if (_cookResult != null) ...[
                    const SizedBox(height: 24),
                    _buildCookSection(),
                  ] else if (_hasResult) ...[
                    const SizedBox(height: 24),
                    _buildNoIngredientHint(),
                  ],
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: _isLoading ? null : const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)]),
        color: _isLoading ? Colors.grey.shade300 : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isLoading ? null : _recommend,
          child: Center(
            child: _isLoading
                ? const Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    SizedBox(width: 12),
                    Text('AI가 고르는 중...', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                  ])
                : const Text('🤖 AI 추천받기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ),
    );
  }

  Widget _buildRetryButton() {
    return GestureDetector(
      onTap: _recommend,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFFF6B35), width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text('🔄 다시 추천받기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFFF6B35))),
        ),
      ),
    );
  }

  Widget _buildNoIngredientHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Text('💡', style: TextStyle(fontSize: 20)),
          SizedBox(width: 10),
          Expanded(
            child: Text('냉장고 탭에서 재료를 등록하면\n여기에 해먹기 추천도 같이 나와요!',
                style: TextStyle(fontSize: 14, color: Color(0xFF636E72), height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildEatOutSection() {
    final picks = (_eatOutResult!['picks'] as List<dynamic>? ?? []).take(2).toList();
    final comment = _eatOutResult!['comment'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (comment.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFFFF6B35).withValues(alpha: 0.08),
                const Color(0xFFFF8E53).withValues(alpha: 0.05),
              ]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text('🤖 $comment', style: const TextStyle(fontSize: 15, height: 1.4)),
          ),
        const SizedBox(height: 16),
        const Text('🏪 내 주변 추천', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ...picks.map((p) {
          final pick = p as Map<String, dynamic>;
          final pickName = pick['name'] as String? ?? '';
          final restaurant = _restaurants.cast<Map<String, dynamic>?>().firstWhere(
            (r) => r!['name'].toString().contains(pickName) || pickName.contains(r['name'].toString()),
            orElse: () => null,
          );

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pickName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(pick['reason'] ?? '', style: const TextStyle(fontSize: 14, color: Color(0xFF636E72), height: 1.4)),
                if (restaurant != null) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.location_on, size: 14, color: Color(0xFFFF6B35)),
                    const SizedBox(width: 4),
                    Expanded(child: Text('${restaurant['address']} · ${restaurant['distance']}m',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF636E72)))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    if ((restaurant['phone'] as String).isNotEmpty)
                      _buildActionButton(Icons.phone, '전화', () => launchUrl(Uri.parse('tel:${restaurant['phone']}'))),
                    const SizedBox(width: 8),
                    _buildActionButton(Icons.map, '지도보기', () => launchUrl(Uri.parse(restaurant['url']))),
                    const SizedBox(width: 8),
                    _buildActionButton(Icons.delivery_dining, '배달', () => _openDeliveryApp(restaurant['name'] as String)),
                  ]),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  void _openDeliveryApp(String storeName) async {
    final encoded = Uri.encodeComponent(storeName);
    // 배민 앱 시도
    final baeminUri = Uri.parse('baemin://search?query=$encoded');
    if (await canLaunchUrl(baeminUri)) {
      await launchUrl(baeminUri, mode: LaunchMode.externalApplication);
      return;
    }
    // 요기요 앱 시도
    final yogiyoUri = Uri.parse('yogiyo://search?query=$encoded');
    if (await canLaunchUrl(yogiyoUri)) {
      await launchUrl(yogiyoUri, mode: LaunchMode.externalApplication);
      return;
    }
    // 둘 다 없으면 배민 웹으로
    await launchUrl(
      Uri.parse('https://baemin.me/search?query=$encoded'),
      mode: LaunchMode.externalApplication,
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
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: const Color(0xFFFF6B35)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFFF6B35))),
        ]),
      ),
    );
  }

  Widget _buildCookSection() {
    final recipes = _cookResult!['recipes'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFF6C5CE7).withValues(alpha: 0.08),
              const Color(0xFFA29BFE).withValues(alpha: 0.05),
            ]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(children: [
            Text('🍳', style: TextStyle(fontSize: 20)),
            SizedBox(width: 10),
            Expanded(child: Text('집에서 해먹기\n냉장고 재료로 만들 수 있는 메뉴예요',
                style: TextStyle(fontSize: 14, color: Color(0xFF636E72), height: 1.4))),
          ]),
        ),
        const SizedBox(height: 12),
        ...recipes.map((r) {
          final recipe = r as Map<String, dynamic>;
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe))),
            child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe['name'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(recipe['reason'] ?? '', style: const TextStyle(fontSize: 14, color: Color(0xFF636E72))),
                if (recipe['ingredients'] != null) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6,
                    children: (recipe['ingredients'] as List<dynamic>).map((i) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: const Color(0xFFF1F2F6), borderRadius: BorderRadius.circular(12)),
                        child: Text(i.toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF636E72))),
                      );
                    }).toList(),
                  ),
                ],
                if (recipe['recipe'] != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
                    child: Text('👨‍🍳 ${recipe['recipe']}',
                        style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF5D4037))),
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

  Widget _buildFilterCard(String title, List<String> options, String? selected, ValueChanged<String> onSelected) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF636E72))),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8,
            children: options.map((option) {
              final isSelected = selected == option;
              return GestureDetector(
                onTap: () => onSelected(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected ? const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)]) : null,
                    color: isSelected ? null : const Color(0xFFF1F2F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(option, style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? Colors.white : const Color(0xFF636E72),
                  )),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
