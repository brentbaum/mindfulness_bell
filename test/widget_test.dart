import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindfulness_bell/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the paused state with the saved interval', (tester) async {
    SharedPreferences.setMockInitialValues({'intervalMinutes': 15});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(420, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MindfulnessBellApp(prefs: prefs));

    expect(find.text('Mindfulness Bell'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('15 min'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });
}
