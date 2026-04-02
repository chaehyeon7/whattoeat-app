import 'package:flutter/material.dart';

class RecommendScreen extends StatefulWidget {
  const RecommendScreen({super.key});

  @override
  State<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends State<RecommendScreen> {
  String? _weight;
  String? _cuisine;
  String? _situation;
  String? _price;
  bool _isLoading = false;

  static const _weights = ['가벼운', '보통', '든든한'];
  static const _cuisines = ['한식', '일식', '중식', '양식', '분식', '동남아'];
  static const _situations = ['혼밥', '회식', '데이트', '안주', '해장'];
  static const _prices = ['~8천', '~1.5만', '상관없음'];

  void _recommend() {
    if (_weight == null || _cuisine == null || _situation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('무게감, 종류, 상황을 선택해주세요')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // TODO: 다음 단계에서 Gemini + 카카오 API 연동
    Future.delayed(const Duration(seconds: 1), () {
      setState(() => _isLoading = false);
    });
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
            _buildFilterSection('상황', _situations, _situation, (v) => setState(() => _situation = v)),
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
                        width: 20,
                        height: 20,
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

            // 결과 영역 (다음 단계에서 채움)
            if (!_isLoading && _weight != null)
              Center(
                child: Text(
                  '다음 단계에서 여기에\n🏪 사먹기 + 🍳 해먹기\n추천 결과가 표시됩니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
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
