import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/gen/app_localizations.dart';
import 'admin/admin_screen.dart';
import 'app_state.dart';
import 'screens/calculator_screen.dart';
import 'screens/compare_screen.dart';
import 'screens/diary_screen.dart';
import 'screens/more_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/today_screen.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2E7D32),
    secondary: const Color(0xFF8D6E63),
    brightness: b,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
    visualDensity: VisualDensity.standard,
  );
}

class AdikeApp extends StatelessWidget {
  final AppState state;
  /// Flutter web build = admin console (hosted at /admin on GitHub Pages).
  final bool adminOnly;
  const AdikeApp({super.key, required this.state, this.adminOnly = kIsWeb});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: Builder(builder: (context) {
        final s = AppScope.of(context);
        return MaterialApp(
          onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: scaffoldMessengerKey,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          locale: s.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: adminOnly ? const AdminScreen() : (s.settings.onboarded ? const HomeShell() : const OnboardingScreen()),
        );
      }),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context);
    _sub = s.fb.foregroundMessages().listen((m) {
      final n = m.notification;
      if (n == null) return;
      scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text('${n.title ?? ''}\n${n.body ?? ''}')));
    });
    if (s.settings.dailySummary && s.fb.available) {
      s.fb.setTopic('daily_summary', true).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    const pages = [TodayScreen(), CompareScreen(), CalculatorScreen(), DiaryScreen(), MoreScreen()];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.today_outlined), selectedIcon: const Icon(Icons.today), label: t.navToday),
          NavigationDestination(icon: const Icon(Icons.bar_chart_outlined), selectedIcon: const Icon(Icons.bar_chart), label: t.navCompare),
          NavigationDestination(icon: const Icon(Icons.calculate_outlined), selectedIcon: const Icon(Icons.calculate), label: t.navCalculator),
          NavigationDestination(icon: const Icon(Icons.menu_book_outlined), selectedIcon: const Icon(Icons.menu_book), label: t.navDiary),
          NavigationDestination(icon: const Icon(Icons.more_horiz), label: t.navMore),
        ],
      ),
    );
  }
}
