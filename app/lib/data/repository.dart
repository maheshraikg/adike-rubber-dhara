import 'dart:convert';

import '../config.dart';
import '../models/models.dart';
import 'cached_http.dart';
import 'mandi_live.dart';

class PriceData {
  final Latest latest;
  final Map<String, Market> markets;
  final Map<String, Variety> varieties;
  final Map<String, Source> sources;
  final bool offline;
  final DateTime fetchedAt;
  const PriceData({
    required this.latest,
    required this.markets,
    required this.varieties,
    required this.sources,
    required this.offline,
    required this.fetchedAt,
  });

  /// Copy with live data.gov.in rows added (see mandi_live.dart).
  PriceData withLive(List<PriceRow> live) {
    if (live.isEmpty) return this;
    return PriceData(
      latest: Latest(
        updatedAt: latest.updatedAt,
        rows: mergeLive(latest.rows, live),
        summary: latest.summary,
        sample: latest.sample,
      ),
      markets: markets,
      varieties: varieties,
      sources: {...sources, MandiLive.sourceId: MandiLive.source},
      offline: offline,
      fetchedAt: fetchedAt,
    );
  }
}

/// Reads the static JSON published on GitHub Pages. Never reads prices from Firestore.
class PriceRepository {
  final CachedHttp http;
  final String base;
  PriceRepository(this.http, {String? baseUrl}) : base = _slash(baseUrl ?? AppConfig.dataBaseUrl);

  static String _slash(String s) => s.endsWith('/') ? s : '$s/';

  String url(String path) => '${base}data/$path';

  Future<PriceData> load() async {
    final results = await Future.wait([
      http.get(url('latest.json')),
      http.get(url('markets.json'), maxAge: const Duration(hours: 12)),
      http.get(url('varieties.json'), maxAge: const Duration(hours: 12)),
      http.get(url('sources.json'), maxAge: const Duration(hours: 6)),
    ]);
    final latest = Latest.fromJson(jsonDecode(results[0].body) as Map<String, dynamic>);
    final markets = {
      for (final m in (jsonDecode(results[1].body) as List)) (m['id'] as String): Market.fromJson(m as Map<String, dynamic>)
    };
    final varieties = {
      for (final v in (jsonDecode(results[2].body) as List)) (v['id'] as String): Variety.fromJson(v as Map<String, dynamic>)
    };
    final sources = {
      for (final s in (jsonDecode(results[3].body) as List)) (s['id'] as String): Source.fromJson(s as Map<String, dynamic>)
    };
    return PriceData(
      latest: latest,
      markets: markets,
      varieties: varieties,
      sources: sources,
      offline: results[0].offline,
      fetchedAt: results[0].fetchedAt,
    );
  }

  /// Offline-first: returns the cached copy without touching the network (or null).
  PriceData? cachedOnly() {
    final l = http.cached(url('latest.json'));
    final m = http.cached(url('markets.json'));
    final v = http.cached(url('varieties.json'));
    final s = http.cached(url('sources.json'));
    if (l == null || m == null || v == null || s == null) return null;
    try {
      return PriceData(
        latest: Latest.fromJson(jsonDecode(l.body) as Map<String, dynamic>),
        markets: {for (final x in (jsonDecode(m.body) as List)) (x['id'] as String): Market.fromJson(x as Map<String, dynamic>)},
        varieties: {for (final x in (jsonDecode(v.body) as List)) (x['id'] as String): Variety.fromJson(x as Map<String, dynamic>)},
        sources: {for (final x in (jsonDecode(s.body) as List)) (x['id'] as String): Source.fromJson(x as Map<String, dynamic>)},
        offline: true,
        fetchedAt: l.fetchedAt,
      );
    } catch (_) {
      return null;
    }
  }

  /// Live mandi rows read on the phone from data.gov.in ([] when unreachable).
  Future<List<PriceRow>> liveMandi(PriceData d) => MandiLive(http).fetch(d.markets, d.varieties);

  Future<History> history(String crop, String marketId) async {
    try {
      final r = await http.get(url('history/$crop/$marketId.json'), maxAge: const Duration(minutes: 30));
      return History.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    } catch (_) {
      return History.empty;
    }
  }
}
