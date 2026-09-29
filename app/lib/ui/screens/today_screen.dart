import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../models/models.dart';
import '../app_state.dart';
import '../widgets/format.dart';
import '../widgets/price_tile.dart';
import 'alerts_screen.dart';
import 'detail_screen.dart';
import 'share_card_screen.dart';
import 'weather_screen.dart';

class CropToggle extends StatelessWidget {
  final String crop;
  final ValueChanged<String> onChanged;
  const CropToggle({super.key, required this.crop, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(value: 'arecanut', label: Text(t.cropArecanut), icon: const Text('🌰')),
        ButtonSegment(value: 'rubber', label: Text(t.cropRubber), icon: const Text('🌳')),
      ],
      selected: {crop},
      onSelectionChanged: (v) => onChanged(v.first),
    );
  }
}

/// Groups rows by market; favourite markets first (in the user's order), then the rest A–Z.
List<MapEntry<String, List<PriceRow>>> groupByMarket(List<PriceRow> rows, List<String> favourites, String Function(String) name) {
  final by = <String, List<PriceRow>>{};
  for (final r in rows) {
    by.putIfAbsent(r.marketId, () => []).add(r);
  }
  for (final l in by.values) {
    l.sort((a, b) {
      final c = a.label(false).compareTo(b.label(false));
      return c != 0 ? c : a.trust.index.compareTo(b.trust.index);
    });
  }
  final favs = [for (final f in favourites) if (by.containsKey(f)) MapEntry(f, by[f]!)];
  final rest = by.entries.where((e) => !favourites.contains(e.key)).toList()
    ..sort((a, b) => name(a.key).compareTo(name(b.key)));
  return [...favs, ...rest];
}

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = AppScope.of(context);
    final data = s.data;
    final rows = s.rowsFor(s.crop);
    final groups = groupByMarket(rows, s.favourites, s.marketName);
    final favCount = groups.where((g) => s.favourites.contains(g.key)).length;
    final summary = data?.latest.summary;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.appTitle),
        actions: [
          IconButton(
            tooltip: t.weatherTitle,
            icon: const Icon(Icons.wb_sunny_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen())),
          ),
          IconButton(
            tooltip: t.alertsTitle,
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsScreen())),
          ),
          IconButton(
            tooltip: t.shareCardTitle,
            icon: const Icon(Icons.share_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShareCardScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: s.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Center(child: CropToggle(crop: s.crop, onChanged: s.setCrop)),
            ),
            if (data?.latest.sample == true) _Banner(text: t.sampleData, color: Colors.orange),
            if (data != null && (data.offline || s.error != null))
              _Banner(text: t.offlineBanner(_fmtTime(data.fetchedAt, s.settings.language)), color: Colors.blueGrey)
            else if (data != null && data.latest.updatedAt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Text(t.lastUpdated(_fmtIso(data.latest.updatedAt, s.settings.language)),
                    style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
              ),
            if (s.loading && data == null) const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator())),
            if (!s.loading && data == null && s.error != null)
              Padding(padding: const EdgeInsets.all(32), child: Text(t.loadError, textAlign: TextAlign.center)),
            if (summary != null && (summary.kn.isNotEmpty || summary.en.isNotEmpty)) _SummaryCard(summary: summary),
            if (data != null && rows.isEmpty)
              Padding(padding: const EdgeInsets.all(32), child: Text(t.noData, textAlign: TextAlign.center)),
            for (var i = 0; i < groups.length; i++) ...[
              if (i == 0 && favCount > 0) _Header(t.myMarkets),
              if (i == favCount && groups.length > favCount) _Header(t.otherMarkets),
              _MarketCard(marketId: groups[i].key, rows: groups[i].value),
            ],
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(t.disclaimer, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtTime(DateTime d, String locale) => DateFormat('d MMM, h:mm a', locale).format(d);
  static String _fmtIso(String iso, String locale) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('d MMM, h:mm a', locale).format(d);
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.secondary)),
      );
}

class _Banner extends StatelessWidget {
  final String text;
  final Color color;
  const _Banner({required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: color.withValues(alpha: 1), fontWeight: FontWeight.w600)),
      );
}

class _SummaryCard extends StatelessWidget {
  final Summary summary;
  const _SummaryCard({required this.summary});
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_awesome, size: 18),
            const SizedBox(width: 6),
            Text(t.summaryTitle, style: theme.textTheme.titleSmall),
            const Spacer(),
            if (summary.date.isNotEmpty) Text(shortDate(summary.date, s.settings.language), style: theme.textTheme.bodySmall),
          ]),
          const SizedBox(height: 6),
          Text(s.kn ? summary.kn : summary.en),
          const SizedBox(height: 4),
          Text(t.summaryNote, style: theme.textTheme.bodySmall),
        ]),
      ),
    );
  }
}

class _MarketCard extends StatelessWidget {
  final String marketId;
  final List<PriceRow> rows;
  const _MarketCard({required this.marketId, required this.rows});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = AppLocalizations.of(context);
    final m = s.market(marketId);
    return Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(children: [
            Text(s.marketName(marketId), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(width: 8),
            if (m != null) Expanded(child: Text(m.district, style: Theme.of(context).textTheme.bodySmall)),
            Text(unitLabel(rows.first.crop, t), style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
        for (final r in rows) ...[
          PriceTile(r, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(row: r)))),
          if (r != rows.last) const Divider(height: 1, indent: 12, endIndent: 12),
        ],
      ]),
    );
  }
}
