import 'package:adike_dhara/ui/app.dart';
import 'package:flutter/material.dart' show SegmentedButton;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('Today shows Kannada rates, favourites first, badges and summary', (tester) async {
    final state = await makeState();
    await state.refresh();
    await tester.pumpWidget(AdikeApp(state: state, adminOnly: false));
    await tester.pumpAndSettle();

    expect(find.text('ಅಡಿಕೆ–ರಬ್ಬರ್ ಧಾರಣೆ'), findsWidgets);
    expect(find.text('ನನ್ನ ಮಾರುಕಟ್ಟೆಗಳು'), findsOneWidget); // favourites header
    expect(find.text('ಇತರ ಮಾರುಕಟ್ಟೆಗಳು'), findsOneWidget);
    // favourite market (Puttur) is listed before Shivamogga
    final putturY = tester.getTopLeft(find.text('ಪುತ್ತೂರು').first).dy;
    final shivY = tester.getTopLeft(find.text('ಶಿವಮೊಗ್ಗ').first).dy;
    expect(putturY < shivY, isTrue);
    // modal shown big with Indian grouping, min–max and badges
    expect(find.text('₹52,500'), findsOneWidget);
    expect(find.textContaining('₹50,000 – ₹53,500'), findsOneWidget);
    expect(find.text('🟢 ಅಧಿಕೃತ'), findsOneWidget);
    expect(find.text('🔵 ಪಾಲುದಾರ'), findsOneWidget);
    expect(find.textContaining('▲ 500'), findsOneWidget);
    expect(find.text('ಇಂದು ರಾಶಿ ಸ್ಥಿರ.'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('ಧಾರಣೆ ಸೂಚಕ ಮಾತ್ರ'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('ಧಾರಣೆ ಸೂಚಕ ಮಾತ್ರ'), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(SegmentedButton<String>), -300, scrollable: find.byType(Scrollable).first);

    // switch crop to rubber
    await tester.tap(find.text('ರಬ್ಬರ್').first);
    await tester.pumpAndSettle();
    expect(find.text('₹190'), findsOneWidget);
    expect(find.text('₹52,500'), findsNothing);
  });

  testWidgets('English toggle and offline banner from cache', (tester) async {
    final online = await makeState(prefs: {'lang': 'en'});
    await online.refresh(); // fills the cache
    // new state with a failing network but the cache from before
    // same SharedPreferences (cache kept), but the network now fails
    final offline = await makeState(prefs: {'lang': 'en'}, client: mockClient(fail: true), reset: false);
    await offline.refresh();
    await tester.pumpWidget(AdikeApp(state: offline, adminOnly: false));
    await tester.pumpAndSettle();
    expect(find.text('Adike–Rubber Dhara'), findsWidgets);
    expect(find.textContaining('Offline'), findsOneWidget);
    expect(find.text('₹45,000'), findsOneWidget);
  });
}
