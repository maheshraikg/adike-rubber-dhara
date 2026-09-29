import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../models/models.dart';
import '../app_state.dart';
import '../widgets/format.dart';
import '../widgets/price_tile.dart';
import 'detail_screen.dart';
import 'today_screen.dart';

/// One variety across markets, sorted by modal (highest first). One row per market:
/// the most trusted, most recent source.
List<PriceRow> compareRows(List<PriceRow> rows, String crop, String variety) {
  final best = <String, PriceRow>{};
  for (final r in rows.where((r) => r.crop == crop && r.variety == variety && r.modal != null)) {
    final cur = best[r.marketId];
    if (cur == null ||
        r.date.compareTo(cur.date) > 0 ||
        (r.date == cur.date && r.trust.index < cur.trust.index)) {
      best[r.marketId] = r;
    }
  }
  return best.values.toList()..sort((a, b) => b.modal!.compareTo(a.modal!));
}

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});
  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  String? variety;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = AppScope.of(context);
    final rows = s.rowsFor(s.crop);
    final varieties = <String, PriceRow>{for (final r in rows) r.variety: r};
    final ids = varieties.keys.toList()..sort((a, b) => varieties[a]!.label(s.kn).compareTo(varieties[b]!.label(s.kn)));
    if (variety == null || !varieties.containsKey(variety)) {
      variety = ids.contains('rashi') ? 'rashi' : (ids.contains('rss4') ? 'rss4' : (ids.isEmpty ? null : ids.first));
    }
    final list = variety == null ? <PriceRow>[] : compareRows(rows, s.crop, variety!);
    return Scaffold(
      appBar: AppBar(title: Text(t.compareTitle)),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Center(child: CropToggle(crop: s.crop, onChanged: (c) => setState(() => s.setCrop(c)))),
        ),
        if (ids.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonFormField<String>(
              initialValue: variety,
              decoration: InputDecoration(labelText: t.variety, border: const OutlineInputBorder()),
              items: [for (final id in ids) DropdownMenuItem(value: id, child: Text(varieties[id]!.label(s.kn)))],
              onChanged: (v) => setState(() => variety = v),
            ),
          ),
        if (list.isEmpty) Padding(padding: const EdgeInsets.all(32), child: Text(t.noData, textAlign: TextAlign.center)),
        if (list.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(unitLabel(s.crop, t), style: Theme.of(context).textTheme.bodySmall),
          ),
        for (final (i, r) in list.indexed)
          Card(
            child: Row(children: [
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
              ),
              Expanded(
                child: PriceTile(r,
                    showMarket: true,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(row: r)))),
              ),
            ]),
          ),
      ]),
    );
  }
}
