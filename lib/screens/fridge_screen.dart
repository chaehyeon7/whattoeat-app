import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/gemini_service.dart';
import '../services/cook_cache_service.dart';
import 'recipe_detail_screen.dart';

class FridgeScreen extends StatefulWidget {
  const FridgeScreen({super.key});

  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<FridgeScreen> {
  final _controller = TextEditingController();
  List<Map<String, String>> _ingredients = [];
  bool _isLoading = false;
  Map<String, dynamic>? _cookResult;

  static const _categories = ['채소', '육류', '해산물', '양념', '기타'];

  static const _categoryEmojis = {
    '채소': '🥬', '육류': '🥩', '해산물': '🐟', '양념': '🧂', '기타': '📦',
  };

  static const _categoryKeywords = {
    '채소': ['배추', '양배추', '상추', '시금치', '브로콜리', '당근', '감자', '고구마', '양파', '대파', '파', '마늘', '생강', '고추', '피망', '파프리카', '오이', '호박', '가지', '토마토', '무', '콩나물', '숙주', '부추', '깻잎', '미나리', '셀러리', '옥수수', '버섯', '팽이', '새송이', '표고', '느타리', '비트', '연근', '우엉', '청경채', '케일', '양상추', '쪽파', '고구마순', '열무', '깐마늘', '아스파라거스'],
    '육류': ['소고기', '돼지', '닭', '오리', '양고기', '베이컨', '햄', '소시지', '삼겹살', '목살', '갈비', '안심', '등심', '다짐육', '불고기', '차돌', '곱창', '대창', '막창', '족발', '보쌈', '닭가슴살', '닭다리', '스팸', '육류', '고기', '牛'],
    '해산물': ['새우', '오징어', '문어', '조개', '홍합', '굴', '전복', '꽃게', '대게', '연어', '참치', '고등어', '갈치', '삼치', '광어', '우럭', '멸치', '미역', '김', '다시마', '어묵', '맛살', '게맛살', '꼬막', '바지락', '해삼', '가리비', '생선', '회', '랍스터'],
    '양념': ['소금', '설탕', '간장', '된장', '고추장', '식초', '참기름', '들기름', '올리브유', '후추', '고춧가루', '카레', '케첩', '마요네즈', '머스타드', '굴소스', '쌈장', '미림', '맛술', '물엿', '꿀', '버터', '치즈', '크림', '우유', '소스', '드레싱', '식용유', '깨'],
  };

  static String _classifyCategory(String name) {
    final lower = name.toLowerCase();
    for (final entry in _categoryKeywords.entries) {
      if (entry.value.any((k) => lower.contains(k) || k.contains(lower))) {
        return entry.key;
      }
    }
    return '기타';
  }

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  Future<void> _loadIngredients() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('ingredients');
    if (data != null) {
      setState(() {
        _ingredients = List<Map<String, String>>.from(
          (jsonDecode(data) as List).map((e) => Map<String, String>.from(e)),
        );
      });
    }
  }

  Future<void> _saveIngredients() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ingredients', jsonEncode(_ingredients));
  }

  void _addIngredient() {
    final name = _controller.text.trim();
    if (name.isEmpty || !RegExp(r'[가-힣a-zA-Z]').hasMatch(name)) return;
    if (_ingredients.length >= 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('재료는 최대 50개까지 등록할 수 있어요!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    if (_ingredients.any((e) => e['name'] == name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('\'$name\' 이미 있어요!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    setState(() {
      _ingredients.insert(0, {'name': name, 'category': _classifyCategory(name)});
      _controller.clear();
    });
    _saveIngredients();
  }

  void _removeIngredient(int index) {
    setState(() => _ingredients.removeAt(index));
    _saveIngredients();
  }

  void _editIngredient(int index) {
    final item = _ingredients[index];
    final editController = TextEditingController(text: item['name']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('재료 수정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: editController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '재료명',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              final newName = editController.text.trim();
              if (newName.isNotEmpty && RegExp(r'[가-힣a-zA-Z]').hasMatch(newName)) {
                setState(() => _ingredients[index]['name'] = newName);
                _saveIngredients();
              }
              Navigator.pop(ctx);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _recommendFromFridge() async {
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('재료를 먼저 추가해주세요!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _cookResult = null;
    });

    try {
      final names = _ingredients.map((e) => e['name']!).toList();
      final result = await GeminiService.recommendCook(
        ingredients: names,
        weight: '상관없음',
        cuisine: '상관없음',
        price: null,
      );
      await CookCacheService.save(result, names);
      setState(() => _cookResult = result);
    } catch (e) {
      debugPrint('[Fridge] 추천 실패: $e');
      if (mounted) {
        final msg = e.toString().contains('SocketException') || e.toString().contains('ClientException')
            ? '인터넷 연결을 확인해주세요!'
            : '추천 실패: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Map<String, String>>>{};
    for (final item in _ingredients) {
      grouped.putIfAbsent(item['category']!, () => []).add(item);
    }

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
                  const Text('🥕 내 냉장고',
                      style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('${_ingredients.length}개 재료 보관 중',
                      style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.85))),
                  const SizedBox(height: 20),
                  // 입력 영역
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: const InputDecoration(
                              hintText: '재료명 입력',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onSubmitted: (_) => _addIngredient(),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _addIngredient,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: Icon(Icons.add, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 냉장고 추천 버튼
          if (_ingredients.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: _isLoading
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)]),
                    color: _isLoading ? Colors.grey.shade300 : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _isLoading ? null : _recommendFromFridge,
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
                                  Text('AI가 레시피 찾는 중...',
                                      style: TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                                ],
                              )
                            : const Text('🍳 이 재료로 뭐 만들지?',
                                style: TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // AI 추천 결과
          if (_cookResult != null)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildCookResultSection(),
                ]),
              ),
            ),

          // 재료 목록
          if (_ingredients.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🧊', style: TextStyle(fontSize: 64)),
                    SizedBox(height: 16),
                    Text('냉장고가 비어있어요',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600,
                            color: Color(0xFF636E72))),
                    SizedBox(height: 8),
                    Text('재료를 추가하면 AI가 요리를 추천해줘요!',
                        style: TextStyle(fontSize: 14, color: Color(0xFFB2BEC3))),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  grouped.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_categoryEmoji(entry.key),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: Color(0xFF636E72))),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: entry.value.map((item) {
                              final index = _ingredients.indexOf(item);
                              return GestureDetector(
                                onTap: () => _editIngredient(index),
                                child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Chip(
                                  label: Text(item['name']!,
                                      style: const TextStyle(fontSize: 14)),
                                  onDeleted: () => _removeIngredient(index),
                                  deleteIconColor: const Color(0xFFFF6B35),
                                  backgroundColor: Colors.white,
                                  side: BorderSide.none,
                                  elevation: 0,
                                ),
                              ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCookResultSection() {
    final comment = _cookResult!['comment'] as String? ?? '';
    final recipes = _cookResult!['recipes'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (comment.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF6C5CE7).withValues(alpha: 0.08),
                const Color(0xFFA29BFE).withValues(alpha: 0.05),
              ]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text('🤖 $comment',
                style: const TextStyle(fontSize: 15, height: 1.4)),
          ),
        const SizedBox(height: 12),
        const Text('🍳 만들 수 있는 요리',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
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
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(recipe['reason'] ?? '',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF636E72))),
                if (recipe['ingredients'] != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: (recipe['ingredients'] as List<dynamic>).map((i) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F2F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(i.toString(),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF636E72))),
                      );
                    }).toList(),
                  ),
                ],
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
          ),
          );
        }),
      ],
    );
  }

  String _categoryEmoji(String category) {
    return '${_categoryEmojis[category] ?? '📦'} $category';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
