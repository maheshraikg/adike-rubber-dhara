import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/weather.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/models.dart';
import '../app_state.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});
  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  String? marketId;
  Future<List<DayWeather>>? future;

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context);
    final markets = s.data?.markets ?? {};
    marketId = s.settings.weatherMarket ??
        s.favourites.firstWhere((id) => markets[id]?.lat != null, orElse: () => markets.containsKey('puttur') ? 'puttur' : (markets.keys.isEmpty ? '' : markets.keys.first));
    _load();
  }

  void _load() {
    final s = AppScope.read(context);
    final m = s.data?.markets[marketId];
    if (m?.lat != null && m?.lon != null) future = s.weather.forecast(m!.lat!, m.lon!);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = AppScope.of(context);
    final markets = (s.data?.markets.values.where((m) => m.lat != null).toList() ?? <Market>[])
      ..sort((a, b) => a.name(s.kn).compareTo(b.name(s.kn)));
    return Scaffold(
      appBar: AppBar(title: Text(t.weatherTitle)),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        if (markets.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: markets.any((m) => m.id == marketId) ? marketId : null,
            decoration: InputDecoration(labelText: t.weatherPlace, border: const OutlineInputBorder()),
            items: [for (final m in markets) DropdownMenuItem(value: m.id, child: Text(m.name(s.kn)))],
            onChanged: (v) {
              s.settings.setWeatherMarket(v!);
              setState(() {
                marketId = v;
                _load();
              });
            },
          ),
        const SizedBox(height: 12),
        if (future != null)
          FutureBuilder<List<DayWeather>>(
            future: future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
              }
              if (snap.hasError) {
                return Column(children: [
                  Text(t.needsOnline),
                  TextButton(onPressed: () => setState(_load), child: Text(t.retry)),
                ]);
              }
              return Column(children: [for (final (i, d) in (snap.data ?? []).indexed) _DayCard(day: d, index: i)]);
            },
          ),
        const SizedBox(height: 12),
        Text(t.dryRule, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Text(t.weatherAttribution, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
      ]),
    );
  }
}

class _DayCard extends StatelessWidget {
  final DayWeather day;
  final int index;
  const _DayCard({required this.day, required this.index});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = AppScope.of(context);
    final (label, color, icon) = switch (day.verdict) {
      DryVerdict.good => (t.dryGood, const Color(0xFF2E7D32), Icons.wb_sunny),
      DryVerdict.risky => (t.dryRisky, const Color(0xFFF9A825), Icons.cloud_queue),
      DryVerdict.bad => (t.dryBad, const Color(0xFFC62828), Icons.umbrella),
    };
    final name = index == 0 ? t.today : (index == 1 ? t.tomorrow : DateFormat('EEEE', s.settings.language).format(day.day));
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
        title: Text('$name · $label', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        subtitle: Text(t.weatherStats(day.rainMm.toStringAsFixed(1), day.humidity.round().toString(), day.cloud.round().toString())),
      ),
    );
  }
}
