import 'package:flutter/material.dart';

class RecommendScreen extends StatelessWidget {
  const RecommendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎰 오늘 뭐먹지'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          '다음 단계에서 구현 예정\n\n필터 선택 → AI 추천\n🏪 사먹기 + 🍳 해먹기',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }
}
