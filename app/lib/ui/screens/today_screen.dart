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

/// Big two-option switch: ಅಡಿಕೆ / ರಬ್ಬರ್.
class CropToggle extends StatelessWidget {
  final String crop;
  final ValueChanged<String> onChanged;
  const CropToggle({super.key, required this.crop, required this.onChanged});

  /// Real photos (Wikimedia Commons, credited in More › Photo credits).
  static const photos = {'arecanut': 'assets/images/arecanut_hero.jpg', 'rubber': 'assets/images/rubber_hero.jpg'};

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    Widget option(String value, String label) {
      final sel = crop == value;
      return Expanded(
        child: Semantics(
          selected: sel,
          button: true,
          label: label,
          child: GestureDetector(
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 92,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: sel ? scheme.primary : Colors.transparent, width: 3),
                boxShadow: sel
                    ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.30), blurRadius: 10, offset: const Offset(0, 4))]
                    : const [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(fit: StackFit.expand, children: [
                  Image.asset(photos[value]!, fit: BoxFit.cover, cacheWidth: 600,
                      errorBuilder: (_, _, _) => ColoredBox(color: scheme.primaryContainer)),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: sel ? 0.05 : 0.35),
                          Colors.black.withValues(alpha: sel ? 0.65 : 0.75),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 8,
                    bottom: 8,
                    child: Row(children: [
                      Expanded(
                        child: Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                shadows: [Shadow(blurRadius: 6, color: Colors.black54)])),
                      ),
                      if (sel) const Icon(Icons.check_circle, color: Colors.white, size: 22),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    return Row(children: [
      option('arecanut', t.cropArecanut),
      const SizedBox(width: 10),
      option('rubber', t.cropRubber),
    ]);
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
        titleSpacing: 16,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.appTitle),
          Text(DateFormat('EEEE, d MMMM', s.settings.language).format(DateTime.now()),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
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
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: CropToggle(crop: s.crop, onChanged: s.setCrop),
            ),
            if (data?.latest.sample == true) _Banner(text: t.sampleData, color: Colors.orange),
            if (data != null && (data.offline || s.error != null))
              _Banner(text: t.offlineBanner(_fmtTime(data.fetchedAt, s.settings.language)), color: Colors.blueGrey)
            else if (data != null && data.latest.updatedAt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.update, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(t.lastUpdated(_fmtIso(data.latest.updatedAt, s.settings.language)),
                        style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ),
            if (s.loading && data == null) const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator())),
            if (!s.loading && data == null && s.error != null)
              Padding(padding: const EdgeInsets.all(32), child: Text(t.loadError, textAlign: TextAlign.center)),
            if (summary != null && (summary.kn.isNotEmpty || summary.en.isNotEmpty)) _SummaryCard(summary: summary),
            if (data != null && rows.isEmpty)
              Padding(padding: const EdgeInsets.all(32), child: Text(t.noData, textAlign: TextAlign.center)),
            for (var i = 0; i < groups.length; i++) ...[
              if (i == 0 && favCount > 0) _Header(t.myMarkets, icon: Icons.star_rounded),
              if (i == favCount && groups.length > favCount) _Header(t.otherMarkets, icon: Icons.storefront_outlined),
              _MarketCard(marketId: groups[i].key, rows: groups[i].value),
            ],
            if (s.liveStatus.isNotEmpty)
              Padding(
                key: const ValueKey('live_status'),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(s.liveStatus.join('\n'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(t.disclaimer, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtTime(DateTime d, String locale) => DateFormat('d MMM, HH:mm', locale).format(d);
  static String _fmtIso(String iso, String locale) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('d MMM, HH:mm', locale).format(d);
  }
}

class _Header extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Header(this.text, {required this.icon});
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 4),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final Color color;
  const _Banner({required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(Icons.info_outline, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ]),
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
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.secondaryContainer],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.auto_awesome, size: 18, color: scheme.onPrimaryContainer),
          const SizedBox(width: 6),
          Text(t.summaryTitle,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer)),
          const Spacer(),
          if (summary.date.isNotEmpty)
            Text(shortDate(summary.date, s.settings.language),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onPrimaryContainer)),
        ]),
        const SizedBox(height: 8),
        Text(s.kn ? summary.kn : summary.en,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5, color: scheme.onPrimaryContainer)),
        const SizedBox(height: 6),
        Text(t.summaryNote,
            style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic, color: scheme.onPrimaryContainer.withValues(alpha: 0.75))),
      ]),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: scheme.surfaceContainer,
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(children: [
            Icon(Icons.location_on, size: 20, color: scheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.marketName(marketId),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                if (m != null && m.district.isNotEmpty) Text(m.district, style: theme.textTheme.bodySmall),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
              child: Text(unitLabel(rows.first.crop, t), style: theme.textTheme.labelSmall),
            ),
          ]),
        ),
        for (final r in rows) ...[
          PriceTile(r, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(row: r)))),
          if (r != rows.last) const Divider(height: 1, indent: 16, endIndent: 16),
        ],
      ]),
    );
  }
}
