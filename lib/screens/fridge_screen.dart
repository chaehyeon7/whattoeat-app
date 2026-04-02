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
      appBar: AppBar(
        title: const Text('🥕 냉장고'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 재료 입력 영역
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 카테고리 선택
                DropdownButton<String>(
                  value: _selectedCategory,
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v!),
                ),
                const SizedBox(width: 12),
                // 재료명 입력
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '재료명 입력',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _addIngredient(),
                  ),
                ),
                const SizedBox(width: 8),
                // 추가 버튼
                FilledButton(
                  onPressed: _addIngredient,
                  child: const Text('추가'),
                ),
              ],
            ),
          ),

          // 재료 개수 표시
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '총 ${_ingredients.length}개 재료',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 재료 목록
          Expanded(
            child: _ingredients.isEmpty
                ? const Center(
                    child: Text(
                      '재료를 추가해주세요!\n냉장고에 있는 것들을 등록하면\nAI가 요리를 추천해줘요 🍳',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: grouped.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 카테고리 헤더
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 4),
                            child: Text(
                              _categoryEmoji(entry.key),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          // 재료 칩 목록
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: entry.value.map((item) {
                              final index = _ingredients.indexOf(item);
                              return Chip(
                                label: Text(item['name']!),
                                onDeleted: () => _removeIngredient(index),
                                deleteIconColor: Colors.red.shade300,
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
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
