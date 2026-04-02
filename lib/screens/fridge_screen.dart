import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FridgeScreen extends StatefulWidget {
  const FridgeScreen({super.key});

  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<FridgeScreen> {
  final _controller = TextEditingController();
  List<Map<String, String>> _ingredients = [];

  static const _categories = ['채소', '육류', '해산물', '양념', '기타'];
  String _selectedCategory = '기타';

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
    if (name.isEmpty) return;
    setState(() {
      _ingredients.add({'name': name, 'category': _selectedCategory});
      _controller.clear();
    });
    _saveIngredients();
  }

  void _removeIngredient(int index) {
    setState(() => _ingredients.removeAt(index));
    _saveIngredients();
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
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('${_ingredients.length}개 재료 보관 중',
                      style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.85))),
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
                        const SizedBox(width: 8),
                        _buildCategoryDropdown(),
                        const SizedBox(width: 8),
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
                              colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _addIngredient,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
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
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF636E72))),
                    SizedBox(height: 8),
                    Text('재료를 추가하면 AI가 요리를 추천해줘요!',
                        style:
                            TextStyle(fontSize: 14, color: Color(0xFFB2BEC3))),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF636E72))),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: entry.value.map((item) {
                              final index = _ingredients.indexOf(item);
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
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

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isDense: true,
          style: const TextStyle(fontSize: 13, color: Color(0xFF2D3436)),
          items: _categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _selectedCategory = v!),
        ),
      ),
    );
  }

  String _categoryEmoji(String category) {
    return switch (category) {
      '채소' => '🥬 채소',
      '육류' => '🥩 육류',
      '해산물' => '🐟 해산물',
      '양념' => '🧂 양념',
      _ => '📦 기타',
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
