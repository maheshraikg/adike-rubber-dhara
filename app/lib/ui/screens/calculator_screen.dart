import 'package:flutter/material.dart';

import '../../data/calculator.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/models.dart';
import '../app_state.dart';
import '../widgets/format.dart';
import 'today_screen.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final qty = TextEditingController();
  final bagKg = TextEditingController(text: '65');
  final rate = TextEditingController();
  final commission = TextEditingController(text: '0');
  final hamali = TextEditingController(text: '0');
  final transport = TextEditingController(text: '0');
  QtyUnit unit = QtyUnit.kg;

  @override
  void dispose() {
    for (final c in [qty, bagKg, rate, commission, hamali, transport]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Today's rate: favourite market first, most trusted source.
  PriceRow? todaysRow(AppState s) {
    final rows = s.rowsFor(s.crop).where((r) => r.modal != null).toList();
    if (rows.isEmpty) return null;
    rows.sort((a, b) {
      final fa = s.favourites.indexOf(a.marketId), fb = s.favourites.indexOf(b.marketId);
      final ra = fa < 0 ? 999 : fa, rb = fb < 0 ? 999 : fb;
      if (ra != rb) return ra.compareTo(rb);
      final pa = (a.variety == 'rashi' || a.variety == 'chali_new' || a.variety == 'rss4') ? 0 : 1;
      final pb = (b.variety == 'rashi' || b.variety == 'chali_new' || b.variety == 'rss4') ? 0 : 1;
      if (pa != pb) return pa.compareTo(pb);
      return a.trust.index.compareTo(b.trust.index);
    });
    return rows.first;
  }

  Future<void> pickRate(AppState s) async {
    final rows = s.rowsFor(s.crop).where((r) => r.modal != null).toList()
      ..sort((a, b) => s.marketName(a.marketId).compareTo(s.marketName(b.marketId)));
    final def = todaysRow(s);
    final picked = await showModalBottomSheet<PriceRow>(
      context: context,
      builder: (c) => ListView(children: [
        if (def != null)
          ListTile(
            leading: const Icon(Icons.star),
            title: Text('${def.label(s.kn)} · ${s.marketName(def.marketId)}'),
            trailing: Text(inr(def.modal)),
            onTap: () => Navigator.pop(c, def),
          ),
        const Divider(),
        for (final r in rows)
          ListTile(
            title: Text('${r.label(s.kn)} · ${s.marketName(r.marketId)}'),
            subtitle: Text(s.sourceName(r.sourceId)),
            trailing: Text(inr(r.modal)),
            onTap: () => Navigator.pop(c, r),
          ),
      ]),
    );
    if (picked != null) setState(() => rate.text = picked.modal!.toStringAsFixed(picked.crop == 'rubber' ? 2 : 0));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = AppScope.of(context);
    final rubber = s.crop == 'rubber';
    final res = calculate(CalcInput(
      qty: parseInput(qty.text) ?? 0,
      unit: unit,
      bagKg: parseInput(bagKg.text) ?? 0,
      rate: parseInput(rate.text) ?? 0,
      ratePerQuintal: !rubber,
      commissionPct: parseInput(commission.text) ?? 0,
      hamali: parseInput(hamali.text) ?? 0,
      transport: parseInput(transport.text) ?? 0,
    ));
    Widget field(TextEditingController c, String label, {String? suffix}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: label, suffixText: suffix, border: const OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(t.calcTitle)),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Center(child: CropToggle(crop: s.crop, onChanged: (c) => setState(() {
              s.setCrop(c);
              rate.clear();
            }))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: field(qty, t.quantity)),
          const SizedBox(width: 8),
          DropdownButton<QtyUnit>(
            value: unit,
            items: [
              DropdownMenuItem(value: QtyUnit.kg, child: Text(t.unitKgShort)),
              DropdownMenuItem(value: QtyUnit.quintal, child: Text(t.unitQuintalShort)),
              DropdownMenuItem(value: QtyUnit.bags, child: Text(t.unitBags)),
            ],
            onChanged: (v) => setState(() => unit = v!),
          ),
        ]),
        if (unit == QtyUnit.bags) field(bagKg, t.bagWeight),
        Row(children: [
          Expanded(child: field(rate, t.rate, suffix: unitLabel(s.crop, t))),
          const SizedBox(width: 8),
          TextButton.icon(onPressed: () => pickRate(s), icon: const Icon(Icons.today), label: Text(t.useTodayRate)),
        ]),
        field(commission, t.commissionPct, suffix: '%'),
        field(hamali, t.hamali),
        field(transport, t.transport),
        const SizedBox(height: 8),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(t.totalKg(plainNum(res.kg))),
              const SizedBox(height: 8),
              _line(t.gross, inr(res.gross)),
              _line(t.deductions, '− ${inr(res.deductions)}'),
              const Divider(),
              _line(t.net, inr(res.net), big: true),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text(t.disclaimer, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _line(String k, String v, {bool big = false}) {
    final style = big ? Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [Expanded(child: Text(k, style: style)), Text(v, key: big ? const Key('netAmount') : null, style: style)]),
    );
  }
}
