import 'package:flutter/material.dart';

class RecipeDetailScreen extends StatelessWidget {
  final Map<String, dynamic> recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final name = recipe['name'] as String? ?? '';
    final reason = recipe['reason'] as String? ?? '';
    final ingredients = recipe['ingredients'] as List<dynamic>? ?? [];
    final recipeText = recipe['recipe'] as String? ?? '';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 헤더
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('🍳 $name',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(reason,
                      style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.85), height: 1.4)),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 필요 재료
                if (ingredients.isNotEmpty) ...[
                  const Text('📋 필요 재료', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: ingredients.map((i) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Text(i.toString(), style: const TextStyle(fontSize: 14)),
                    )).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // 레시피
                if (recipeText.isNotEmpty) ...[
                  const Text('👨‍🍳 만드는 법', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(recipeText,
                        style: const TextStyle(fontSize: 15, height: 1.8, color: Color(0xFF5D4037))),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
