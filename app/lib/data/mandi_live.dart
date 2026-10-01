/// Live APMC mandi prices read on the phone from data.gov.in (Agmarknet).
///
/// data.gov.in refuses connections from GitHub's servers, so the collection
/// robot cannot reach it; phones in India can. This uses the public sample key
/// that data.gov.in shows on every dataset page (not a secret; at most 10
/// records per request, so results are paged in tens).
///
/// Only figures printed by data.gov.in are used. A row is shown only when its
/// market and variety match the published lists and it passes the same basic
/// checks as the robot (modal present, min ≤ modal ≤ max, sane range);
/// anything else is dropped rather than guessed.
library;

import 'dart:convert';

import '../models/models.dart';
import 'cached_http.dart';

class MandiLive {
  static const sourceId = 'datagov_live';
  static const sampleKey = '579b464db66ec23bdd000001cdd3946e44ce4aad7209ff7b23ac571b';
  static const resourceUrl = 'https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070';
  static const pageSize = 10;
  static const maxPages = 15;

  static const queries = [
    (state: 'Karnataka', commodity: 'Arecanut(Betelnut/Supari)', crop: 'arecanut'),
    (state: 'Kerala', commodity: 'Rubber', crop: 'rubber'),
    (state: 'Karnataka', commodity: 'Rubber', crop: 'rubber'),
  ];

  static const source = Source(
    id: sourceId,
    nameEn: 'APMC mandi (data.gov.in, live)',
    nameKn: 'ಎಪಿಎಂಸಿ ಮಂಡಿ ಧಾರಣೆ (data.gov.in, ನೇರ)',
    trust: Trust.official,
    url: 'https://data.gov.in',
    kind: 'api',
  );

  final CachedHttp http;
  MandiLive(this.http);

  static String pageUrl(String state, String commodity, int offset, {required bool keyword}) {
    final f = keyword ? '.keyword' : '';
    final q = {
      'api-key': sampleKey,
      'format': 'json',
      'limit': '$pageSize',
      'offset': '$offset',
      'filters[state$f]': state,
      'filters[commodity$f]': commodity,
    };
    return Uri.parse(resourceUrl).replace(queryParameters: q).toString();
  }

  /// All records for one query. Tries `filters[x.keyword]`, then plain `filters[x]`
  /// (data.gov.in accepts one or the other depending on the dataset).
  Future<List<Map<String, dynamic>>> _records(String state, String commodity) async {
    for (final keyword in [true, false]) {
      final out = <Map<String, dynamic>>[];
      for (var page = 0; page < maxPages; page++) {
        final r = await http.get(pageUrl(state, commodity, page * pageSize, keyword: keyword),
            maxAge: const Duration(minutes: 30), timeout: const Duration(seconds: 20));
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        final recs = ((data['records'] ?? []) as List).cast<Map<String, dynamic>>();
        out.addAll(recs);
        final total = int.tryParse('${data['total'] ?? 0}') ?? 0;
        if (recs.length < pageSize || out.length >= total) break;
      }
      if (out.isNotEmpty) return out;
    }
    return const [];
  }

  /// Fetch and parse every query. Failures of one query don't stop the others.
  Future<List<PriceRow>> fetch(Map<String, Market> markets, Map<String, Variety> varieties, {DateTime? now}) async {
    final rows = <PriceRow>[];
    final m = NameMatcher(markets.values, varieties.values);
    for (final q in queries) {
      try {
        rows.addAll(parseRecords(await _records(q.state, q.commodity), q.crop, m, now: now ?? DateTime.now()));
      } catch (_) {
        // offline / data.gov.in down: published prices still show
      }
    }
    return rows;
  }
}

String _clean(String? s) {
  if (s == null) return '';
  const kn = '೦೧೨೩೪೫೬೭೮೯';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().trim().split('')) {
    final i = kn.indexOf(ch);
    b.write(i >= 0 ? '$i' : ch);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ');
}

/// Market / variety name → id, using the aliases published with the lists
/// (same rules as the pipeline's normalizer).
class NameMatcher {
  final Map<String, String> _market = {};
  final Map<String, String> _variety = {};
  final Map<String, Variety> varieties = {};

  NameMatcher(Iterable<Market> markets, Iterable<Variety> vars) {
    for (final m in markets) {
      for (final a in [m.id, m.en, m.kn, ...m.aliases]) {
        _market[_clean(a)] = m.id;
      }
    }
    for (final v in vars) {
      varieties[v.id] = v;
      for (final a in [v.id, v.en, v.kn, ...v.aliases]) {
        _variety['${v.crop}|${_clean(a)}'] = v.id;
      }
    }
  }

  String? market(String? raw) {
    final c = _clean(raw);
    if (c.isEmpty) return null;
    if (_market.containsKey(c)) return _market[c];
    // "Puttur APMC", "Shimoga(Theerthahalli)": try the parts
    for (final part in c.split(RegExp(r'[()/,\-]| apmc| market| mandi'))) {
      final p = part.trim();
      if (_market.containsKey(p)) return _market[p];
    }
    return null;
  }

  String? variety(String crop, String? raw) {
    final c = _clean(raw);
    if (c.isEmpty) return null;
    final hit = _variety['$crop|$c'];
    if (hit != null) return hit;
    final c2 = c.replaceAll(RegExp(r'[()\[\]]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return _variety['$crop|$c2'];
  }
}

double? _num(dynamic v) {
  if (v == null) return null;
  final s = v.toString().replaceAll(',', '').trim();
  return s.isEmpty ? null : double.tryParse(s);
}

/// dd/mm/yyyy (data.gov.in) → yyyy-mm-dd.
String? _isoDate(dynamic v) {
  final m = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})$').firstMatch('${v ?? ''}'.trim());
  if (m == null) return null;
  final d = DateTime.tryParse('${m[3]}-${m[2]!.padLeft(2, '0')}-${m[1]!.padLeft(2, '0')}');
  return d?.toIso8601String().substring(0, 10);
}

/// Same sanity ranges as the pipeline (config.DEFAULT_VALIDATION).
const _range = {'arecanut': (5000.0, 150000.0), 'rubber': (50.0, 500.0)};

List<PriceRow> parseRecords(List<Map<String, dynamic>> records, String crop, NameMatcher m, {required DateTime now}) {
  final out = <String, PriceRow>{};
  final today = DateTime(now.year, now.month, now.day);
  for (final rec in records) {
    final market = m.market(rec['market'] as String?);
    var vraw = (rec['variety'] ?? '').toString();
    final grade = (rec['grade'] ?? '').toString().trim();
    if (grade.isNotEmpty && !['FAQ', 'NON-FAQ', 'LOCAL'].contains(grade.toUpperCase())) {
      vraw = '$vraw $grade'.trim();
    }
    final variety = m.variety(crop, vraw);
    final date = _isoDate(rec['arrival_date']);
    if (market == null || variety == null || date == null) continue;
    final d = DateTime.parse(date);
    if (d.isAfter(today) || today.difference(d).inDays > 7) continue; // future / stale

    final f = crop == 'rubber' ? 0.01 : 1.0; // data.gov.in quotes ₹/quintal
    double? conv(double? x) => x == null ? null : (x * f * 100).roundToDouble() / 100;
    final min = conv(_num(rec['min_price'])), max = conv(_num(rec['max_price'])), modal = conv(_num(rec['modal_price']));
    if (modal == null) continue;
    if (min != null && max != null && min > max) continue;
    if ((min != null && modal < min) || (max != null && modal > max)) continue;
    final (lo, hi) = _range[crop]!;
    if (modal < lo || modal > hi) continue;

    final v = m.varieties[variety]!;
    final row = PriceRow(
      crop: crop,
      variety: variety,
      labelKn: v.kn,
      labelEn: v.en,
      marketId: market,
      sourceId: MandiLive.sourceId,
      trust: Trust.official,
      unit: crop == 'rubber' ? 'INR/kg' : 'INR/quintal',
      date: date,
      min: min,
      max: max,
      modal: modal,
    );
    final prev = out['$market|$variety'];
    if (prev == null || prev.date.compareTo(date) < 0) out['$market|$variety'] = row; // newest per market+variety
  }
  return out.values.toList();
}

/// Adds live rows the published file doesn't already cover with an equal or
/// newer date for the same crop, market and variety.
List<PriceRow> mergeLive(List<PriceRow> published, List<PriceRow> live) {
  final newest = <String, String>{};
  for (final r in published) {
    final k = '${r.crop}|${r.marketId}|${r.variety}';
    final d = newest[k];
    if (d == null || d.compareTo(r.date) < 0) newest[k] = r.date;
  }
  return [
    ...published,
    for (final r in live)
      if ((newest['${r.crop}|${r.marketId}|${r.variety}'] ?? '').compareTo(r.date) < 0) r,
  ];
}
