import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../data/mandi_live.dart';
import '../../models/models.dart';
import '../app_state.dart';
import '../widgets/badges.dart';
import '../widgets/format.dart';
import '../widgets/price_tile.dart';
import 'alerts_screen.dart';

enum ChartRange { d7, m1, m6, y1 }

extension on ChartRange {
  int get days => switch (this) { ChartRange.d7 => 7, ChartRange.m1 => 30, ChartRange.m6 => 182, ChartRange.y1 => 365 };
}

/// Points within [range] ending at [end], plus the same window one year earlier (season compare).
({List<HistPoint> current, List<HistPoint> lastYear}) windowed(List<HistPoint> pts, ChartRange range, DateTime end) {
  final from = end.subtract(Duration(days: range.days));
  final lyEnd = DateTime(end.year - 1, end.month, end.day);
  final lyFrom = lyEnd.subtract(Duration(days: range.days));
  return (
    current: pts.where((p) => !p.date.isBefore(from) && !p.date.isAfter(end) && p.modal != null).toList(),
    lastYear: pts.where((p) => !p.date.isBefore(lyFrom) && !p.date.isAfter(lyEnd) && p.modal != null).toList(),
  );
}

class DetailScreen extends StatefulWidget {
  final PriceRow row;
  const DetailScreen({super.key, required this.row});
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  History? history;
  // live data.gov.in rows only have the last 7 days
  late ChartRange range = widget.row.sourceId == MandiLive.sourceId ? ChartRange.d7 : ChartRange.m1;
  bool season = false;

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context);
    final r = widget.row;
    final load = r.sourceId == MandiLive.sourceId
        ? s.repo.historyWithLive(r.crop, r.marketId, s.data)
        : s.repo.history(r.crop, r.marketId);
    load.then((h) {
      if (mounted) setState(() => history = h);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = AppScope.of(context);
    final r = widget.row;
    final theme = Theme.of(context);
    final pts = history?.of(r.sourceId, r.variety) ?? const <HistPoint>[];
    final end = DateTime.tryParse(r.date) ?? DateTime.now();
    final w = windowed(pts, range, end);
    final others = s.rows.where((x) => x.crop == r.crop && x.variety == r.variety && x.marketId == r.marketId).toList()
      ..sort((a, b) => a.trust.index.compareTo(b.trust.index));
    final recent = pts.reversed.take(10).toList();

    return Scaffold(
      appBar: AppBar(title: Text('${r.label(s.kn)} · ${s.marketName(r.marketId)}')),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Card(child: PriceTile(r)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(spacing: 8, children: [
            for (final (rg, label) in [
              (ChartRange.d7, t.range7d),
              (ChartRange.m1, t.range1m),
              (ChartRange.m6, t.range6m),
              (ChartRange.y1, t.range1y),
            ])
              ChoiceChip(label: Text(label), selected: range == rg, onSelected: (_) => setState(() => range = rg)),
            FilterChip(label: Text(t.seasonCompare), selected: season, onSelected: (v) => setState(() => season = v)),
          ]),
        ),
        SizedBox(
          height: 240,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            child: history == null
                ? const Center(child: CircularProgressIndicator())
                : w.current.length < 2
                    ? Center(child: Text(t.noHistory))
                    : PriceChart(current: w.current, lastYear: season ? w.lastYear : const [], rubber: r.crop == 'rubber'),
          ),
        ),
        if (season && w.current.length >= 2)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _legend(theme.colorScheme.primary, t.thisYear),
              const SizedBox(width: 16),
              _legend(theme.colorScheme.secondary, t.seasonCompare),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(t.setAlert),
              onPressed: () => showCreateAlertDialog(context, r),
            ),
            OutlinedButton.icon(icon: const Icon(Icons.share), label: Text(t.share), onPressed: () => _share(context)),
            OutlinedButton.icon(
              icon: const Icon(Icons.flag_outlined),
              label: Text(t.reportWrong),
              onPressed: () => _report(context),
            ),
          ]),
        ),
        if (others.length > 1) ...[
          _title(context, t.allSources),
          Card(
            child: Column(children: [
              for (final o in others)
                ListTile(
                  leading: TrustBadge(o.trust, compact: true),
                  title: Text(s.sourceName(o.sourceId)),
                  subtitle: Text('${shortDate(o.date, s.settings.language)} ${o.time} · ${inr(o.min)} – ${inr(o.max)}'),
                  trailing: Text(inr(o.modal), style: theme.textTheme.titleMedium),
                ),
            ]),
          ),
        ],
        if (recent.isNotEmpty) ...[
          _title(context, t.recentDays),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Table(
                columnWidths: const {0: FlexColumnWidth(1.2)},
                children: [
                  TableRow(children: [
                    for (final h in [t.dateLabel, t.minLabel, t.maxLabel, t.modal])
                      Padding(padding: const EdgeInsets.all(4), child: Text(h, style: theme.textTheme.labelMedium)),
                  ]),
                  for (final p in recent)
                    TableRow(children: [
                      Padding(padding: const EdgeInsets.all(4), child: Text(DateFormat('d MMM yy', s.settings.language).format(p.date))),
                      Padding(padding: const EdgeInsets.all(4), child: Text(inr(p.min))),
                      Padding(padding: const EdgeInsets.all(4), child: Text(inr(p.max))),
                      Padding(padding: const EdgeInsets.all(4), child: Text(inr(p.modal), style: const TextStyle(fontWeight: FontWeight.w600))),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _legend(Color c, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 14, height: 3, color: c), const SizedBox(width: 4), Text(label)]);

  Widget _title(BuildContext context, String s) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(s, style: Theme.of(context).textTheme.titleMedium),
      );

  void _share(BuildContext context) {
    final s = AppScope.read(context);
    final t = AppLocalizations.of(context);
    final r = widget.row;
    final text = '${r.label(s.kn)} · ${s.marketName(r.marketId)} (${shortDate(r.date, s.settings.language)})\n'
        '${t.modal}: ${inr(r.modal)} ${unitLabel(r.crop, t)}\n'
        '${t.minLabel}–${t.maxLabel}: ${inr(r.min)} – ${inr(r.max)}\n'
        '${s.sourceName(r.sourceId)}\n— ${t.appTitle}';
    SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _report(BuildContext context) async {
    final s = AppScope.read(context);
    final t = AppLocalizations.of(context);
    if (!s.fb.available) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.notConfigured)));
      return;
    }
    String reason = 'price';
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(t.reportTitle),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            RadioGroup<String>(
              groupValue: reason,
              onChanged: (v) => set(() => reason = v!),
              child: Column(children: [
                for (final (v, l) in [('price', t.reportPrice), ('date', t.reportDate), ('other', t.reportOther)])
                  RadioListTile<String>(value: v, title: Text(l)),
              ]),
            ),
            TextField(controller: note, maxLength: 500, decoration: InputDecoration(labelText: t.diaryNote)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.cancel)),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t.submit)),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await s.fb.reportWrongRate(widget.row.key, reason, note.text.trim());
      messenger.showSnackBar(SnackBar(content: Text(t.reportSent)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(t.errorGeneric('$e'))));
    }
  }
}

class PriceChart extends StatelessWidget {
  final List<HistPoint> current, lastYear;
  final bool rubber;
  const PriceChart({super.key, required this.current, this.lastYear = const [], this.rubber = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = current.first.date;
    double x(DateTime d) => d.difference(base).inDays.toDouble();
    final spots = [for (final p in current) FlSpot(x(p.date), p.modal!)];
    // shift last year's points forward by one year so they align with this season
    final ly = [
      for (final p in lastYear) FlSpot(x(DateTime(p.date.year + 1, p.date.month, p.date.day)), p.modal!),
    ];
    final ys = [...spots, ...ly].map((s) => s.y);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    final pad = math.max((maxY - minY) * 0.1, rubber ? 1.0 : 100.0);
    final span = spots.last.x - spots.first.x;
    final fmt = DateFormat(span > 60 ? 'MMM' : 'd/M');
    return LineChart(LineChartData(
      minY: minY - pad,
      maxY: maxY + pad,
      gridData: const FlGridData(drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (items) => items
              .map((i) => LineTooltipItem(
                  '${DateFormat('d MMM yy').format(base.add(Duration(days: i.x.round())))}\n${inr(i.y)}',
                  TextStyle(color: theme.colorScheme.onInverseSurface)))
              .toList(),
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 56,
            getTitlesWidget: (v, meta) => (v == meta.max || v == meta.min)
                ? const SizedBox.shrink()
                : SideTitleWidget(
              meta: meta,
              child: Text(rubber ? v.toStringAsFixed(0) : '${(v / 1000).toStringAsFixed(1)}k', style: const TextStyle(fontSize: 10)),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            interval: math.max(1, span / 4),
            getTitlesWidget: (v, meta) => SideTitleWidget(
              meta: meta,
              child: Text(fmt.format(base.add(Duration(days: v.round()))), style: const TextStyle(fontSize: 10)),
            ),
          ),
        ),
      ),
      lineBarsData: [
        if (ly.length >= 2)
          LineChartBarData(
            spots: ly,
            color: theme.colorScheme.secondary,
            barWidth: 2,
            dashArray: [4, 4],
            dotData: const FlDotData(show: false),
          ),
        LineChartBarData(
          spots: spots,
          color: theme.colorScheme.primary,
          barWidth: 3,
          dotData: FlDotData(show: spots.length <= 10),
          belowBarData: BarAreaData(show: true, color: theme.colorScheme.primary.withValues(alpha: 0.08)),
        ),
      ],
    ));
  }
}
