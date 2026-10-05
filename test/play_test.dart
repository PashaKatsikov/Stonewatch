import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonewatch/play/play_page.dart';
import 'package:stonewatch/play/stage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('playfield lays out and a drop resolves', (tester) async {
    SharedPreferences.setMockInitialValues({'hint_done': true});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpWidget(MaterialApp(home: PlayPage(prefs: prefs)));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(Stage), findsOneWidget);
    expect(find.text('ID : 0'), findsOneWidget);
    expect(find.textContaining('FUN'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.bySemanticsLabel('Build'));
    await tester.pump();
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.text('CASHOUT'), findsOneWidget);
    expect(find.text('Results'), findsOneWidget);
    expect(find.text('Your bet is placed!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
