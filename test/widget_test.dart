import 'package:flutter_test/flutter_test.dart';
import 'package:whattoeat/main.dart';

void main() {
  testWidgets('App renders', (tester) async {
    await tester.pumpWidget(const WhatToEatApp());
    expect(find.text('냉장고'), findsOneWidget);
  });
}
