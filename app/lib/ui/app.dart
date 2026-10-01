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

/// Brand colours: areca green + husk brown.
const brandGreen = Color(0xFF2E7D32);
const brandBrown = Color(0xFF8D6E63);

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: brandGreen, secondary: brandBrown, brightness: b);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
  // Roboto (system) for Latin/digits, bundled Noto Sans Kannada for Kannada.
  final text = base.textTheme.apply(fontFamilyFallback: const ['NotoSansKannada']);
  return base.copyWith(
    textTheme: text,
    primaryTextTheme: base.primaryTextTheme.apply(fontFamilyFallback: const ['NotoSansKannada']),
    scaffoldBackgroundColor: scheme.surfaceContainerLowest,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 1,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    chipTheme: base.chipTheme.copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: scheme.surfaceContainerLow,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(text.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5), space: 1),
  );
}

class AdikeApp extends StatelessWidget {
  final AppState state;
  /// Flutter web build = admin console (hosted at /admin on GitHub Pages).
  final bool adminOnly;
  const AdikeApp({super.key, required this.state, this.adminOnly = kIsWeb && !const bool.fromEnvironment('FARMER_WEB')});

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
