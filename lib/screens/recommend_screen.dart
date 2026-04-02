import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/gemini_service.dart';

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
  Map<String, dynamic>? _result;

  static const _weights = ['가벼운', '보통', '든든한'];
  static const _cuisines = ['한식', '일식', '중식', '양식', '분식', '동남아'];
  static const _prices = ['~8천', '~1.5만', '상관없음'];

  Future<List<String>> _getIngredients() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('ingredients');
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list.map((e) => e['name'] as String).toList();
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
      _result = null;
    });

    try {
      final ingredients = await _getIngredients();
      final result = await GeminiService.recommendCook(
        ingredients: ingredients,
        weight: _weight!,
        cuisine: _cuisine!,
        price: _price,
      );
      setState(() => _result = result);
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
            _buildFilterSection('무게감', _weights, _weight, (v) => setState(() => _weight = v)),
            const SizedBox(height: 16),
            _buildFilterSection('종류', _cuisines, _cuisine, (v) => setState(() => _cuisine = v)),
            const SizedBox(height: 16),
            _buildFilterSection('가격대', _prices, _price, (v) => setState(() => _price = v)),
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
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isLoading ? 'AI가 고르는 중...' : '🤖 AI 추천받기'),
                style: FilledButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 해먹기 결과
            if (_result != null) _buildCookResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildCookResult() {
    final recipes = _result!['recipes'] as List<dynamic>? ?? [];
    final comment = _result!['comment'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI 한마디
        if (comment.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('🤖 $comment', style: const TextStyle(fontSize: 15)),
          ),
        const SizedBox(height: 16),

        // 해먹기 섹션
        const Text('🍳 해먹기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...recipes.map((r) => _buildRecipeCard(r as Map<String, dynamic>)),

        // 사먹기 (다음 단계)
        const SizedBox(height: 24),
        Center(
          child: Text(
            '🏪 사먹기 추천은 다음 단계에서 구현됩니다',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
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
            Text(
              recipe['name'] ?? '',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              recipe['reason'] ?? '',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            // 재료 표시
            if (recipe['ingredients'] != null)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: (recipe['ingredients'] as List<dynamic>).map((i) {
                  return Chip(
                    label: Text(i.toString(), style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            const SizedBox(height: 8),
            // 레시피
            if (recipe['recipe'] != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  recipe['recipe'],
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(
    String title,
    List<String> options,
    String? selected,
    ValueChanged<String> onSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selected == option;
            return ChoiceChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (_) => onSelected(option),
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
            );
          }).toList(),
        ),
      ],
    );
  }
}
