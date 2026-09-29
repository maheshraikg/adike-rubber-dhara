import 'package:adike_dhara/data/calculator.dart';
import 'package:adike_dhara/ui/app_state.dart';
import 'package:adike_dhara/ui/screens/calculator_screen.dart';
import 'package:adike_dhara/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('calculate: quintal rate, kg / quintal / bags, deductions', () {
    final r = calculate(const CalcInput(qty: 2, unit: QtyUnit.quintal, rate: 50000, ratePerQuintal: true, commissionPct: 2, hamali: 100, transport: 0));
    expect(r.kg, 200);
    expect(r.gross, 100000);
    expect(r.commission, 2000);
    expect(r.net, 97900);
    final bags = calculate(const CalcInput(qty: 3, unit: QtyUnit.bags, bagKg: 65, rate: 50000, ratePerQuintal: true));
    expect(bags.kg, 195);
    expect(bags.gross, 97500);
    final rubber = calculate(const CalcInput(qty: 150, unit: QtyUnit.kg, rate: 190.5, ratePerQuintal: false, transport: 50));
    expect(rubber.gross, 28575);
    expect(rubber.net, 28525);
  });

  testWidgets('Calculator shows net in Indian format and uses today\'s rate', (tester) async {
    final state = await makeState(prefs: {'lang': 'en'});
    await state.refresh();
    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const CalculatorScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Quantity'), '250');
    await tester.enterText(find.widgetWithText(TextField, 'Rate'), '52500');
    await tester.enterText(find.widgetWithText(TextField, 'Commission %'), '2');
    await tester.enterText(find.widgetWithText(TextField, 'Hamali (₹)'), '150');
    await tester.pump();
    // 250 kg × ₹52,500/qtl = ₹1,31,250; −2% (2,625) −150 = ₹1,28,475
    expect(find.text('₹1,31,250'), findsOneWidget);
    expect(find.byKey(const Key('netAmount')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('netAmount'))).data, '₹1,28,475');

    // "Use today's rate" picks the favourite market (Puttur, ₹45,000)
    await tester.tap(find.text("Use today's rate"));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.star));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '45000'), findsOneWidget);
  });
}
