import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../models/models.dart';
import '../app.dart';
import '../app_state.dart';

String regionLabel(String r, AppLocalizations t) => switch (r) {
      'coastal' => t.regionCoastal,
      'malnad' => t.regionMalnad,
      'kerala' => t.regionKerala,
      _ => t.regionOther,
    };

/// Market multi-picker grouped by region. Used on first launch and from Settings.
class MarketPicker extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  const MarketPicker({super.key, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = AppLocalizations.of(context);
    final markets = s.data?.markets.values.toList() ?? <Market>[];
    if (markets.isEmpty) {
      return Center(child: s.loading ? const CircularProgressIndicator() : Text(t.loadError, textAlign: TextAlign.center));
    }
    const order = ['coastal', 'malnad', 'other', 'kerala'];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final region in order) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
            child: Text(regionLabel(region, t), style: Theme.of(context).textTheme.titleSmall),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in markets.where((m) => m.region == region))
              FilterChip(
                label: Text(m.name(s.kn)),
                selected: selected.contains(m.id),
                onSelected: (_) => onToggle(m.id),
              ),
          ]),
        ],
      ],
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  final bool editing;
  const OnboardingScreen({super.key, this.editing = false});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late Set<String> selected;

  @override
  void initState() {
    super.initState();
    selected = AppScope.read(context).favourites.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.pickMarketsTitle),
        actions: [
          if (!widget.editing)
            TextButton(
              onPressed: () => s.setLanguage(s.kn ? 'en' : 'kn'),
              child: Text(s.kn ? 'English' : 'ಕನ್ನಡ'),
            ),
        ],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text(t.pickMarketsHint)),
        Expanded(
          child: MarketPicker(
            selected: selected,
            onToggle: (id) => setState(() => selected.contains(id) ? selected.remove(id) : selected.add(id)),
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: () async {
              await s.setFavourites(selected.toList());
              if (!context.mounted) return;
              if (widget.editing) {
                Navigator.pop(context);
              } else {
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell()));
              }
            },
            child: Text(t.continueLabel),
          ),
        ),
      ),
    );
  }
}
