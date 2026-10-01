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

  static const historyUrl = 'https://api.data.gov.in/resource/35985678-0d79-46b4-9ed6-6f13308a1d24';

  /// Filter spellings for the history dataset (capitalised field names), with a
  /// lowercase fallback; date as dd/mm/yyyy, then yyyy-mm-dd.
  static const _histStyles = [('State', 'Commodity', 'Arrival_Date'), ('state', 'commodity', 'arrival_date')];

  static String historyPageUrl(String state, String commodity, String date, int offset, int style) {
    final (fs, fc, fd) = _histStyles[style];
    return Uri.parse(historyUrl).replace(queryParameters: {
      'api-key': sampleKey,
      'format': 'json',
      'limit': '$pageSize',
      'offset': '$offset',
      'filters[$fs]': state,
      'filters[$fc]': commodity,
      'filters[$fd]': date,
    }).toString();
  }

  static String _dmy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  static String _ymd(DateTime d) => d.toIso8601String().substring(0, 10);

  Future<List<Map<String, dynamic>>> _dayRecords(String state, String commodity, String date, int style, Duration maxAge) async {
    final out = <Map<String, dynamic>>[];
    for (var page = 0; page < maxPages; page++) {
      final r = await http.get(historyPageUrl(state, commodity, date, page * pageSize, style),
          maxAge: maxAge, timeout: const Duration(seconds: 20));
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final recs = ((data['records'] ?? []) as List).cast<Map<String, dynamic>>();
      out.addAll(recs);
      final total = int.tryParse('${data['total'] ?? 0}') ?? 0;
      if (recs.length < pageSize || out.length >= total) break;
    }
    return out;
  }

  /// Last [days] days of prices for one market, by variety, from data.gov.in's
  /// variety-wise history dataset (plus the current dataset). Past days are
  /// cached for 12 h, today for 30 min. Empty when unreachable.
  Future<Map<String, List<HistPoint>>> history(String crop, String marketId, Map<String, Market> markets,
      Map<String, Variety> varieties, {int days = 7, DateTime? now}) async {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final m = NameMatcher(markets.values, varieties.values);
    final rows = <PriceRow>[];
    for (final q in queries.where((q) => q.crop == crop)) {
      // find the filter spelling + date format that this dataset answers to
      (int, String Function(DateTime))? fmt;
      for (var back = 0; back < days && fmt == null; back++) {
        final d = today.subtract(Duration(days: back));
        for (final style in [0, 1]) {
          for (final f in [_dmy, _ymd]) {
            if (fmt != null) break;
            try {
              final recs = await _dayRecords(q.state, q.commodity, f(d), style,
                  back == 0 ? const Duration(minutes: 30) : const Duration(hours: 12));
              if (recs.isNotEmpty) {
                fmt = (style, f);
                rows.addAll(parseRecords(recs, crop, m, now: n, newestOnly: false));
              }
            } catch (_) {}
          }
        }
        if (fmt == null && back >= 2) break; // nothing for 3 days in any spelling: give up
      }
      if (fmt == null) continue;
      final (style, f) = fmt;
      for (var back = 0; back < days; back++) {
        final d = today.subtract(Duration(days: back));
        if (rows.any((r) => r.date == _ymd(d))) continue; // already fetched while probing
        try {
          final recs = await _dayRecords(q.state, q.commodity, f(d), style,
              back == 0 ? const Duration(minutes: 30) : const Duration(hours: 12));
          rows.addAll(parseRecords(recs, crop, m, now: n, newestOnly: false));
        } catch (_) {}
      }
    }
    try {
      for (final q in queries.where((q) => q.crop == crop)) {
        rows.addAll(parseRecords(await _records(q.state, q.commodity), crop, m, now: n, newestOnly: false));
      }
    } catch (_) {}
    return historyByVariety(rows.where((r) => r.marketId == marketId));
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

/// Field lookup across both datasets: current uses `min_price`, the history
/// dataset `Min_x0020_Price` / `Arrival_Date`.
dynamic _field(Map<String, dynamic> rec, String name) {
  if (rec.containsKey(name)) return rec[name];
  for (final e in rec.entries) {
    if (e.key.toLowerCase().replaceAll('_x0020_', '_') == name) return e.value;
  }
  return null;
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

/// [newestOnly]: one row per market+variety (Today); otherwise one per day (history).
List<PriceRow> parseRecords(List<Map<String, dynamic>> records, String crop, NameMatcher m,
    {required DateTime now, bool newestOnly = true}) {
  final out = <String, PriceRow>{};
  final today = DateTime(now.year, now.month, now.day);
  for (final rec in records) {
    final market = m.market(_field(rec, 'market')?.toString());
    var vraw = (_field(rec, 'variety') ?? '').toString();
    final grade = (_field(rec, 'grade') ?? '').toString().trim();
    if (grade.isNotEmpty && !['FAQ', 'NON-FAQ', 'LOCAL'].contains(grade.toUpperCase())) {
      vraw = '$vraw $grade'.trim();
    }
    final variety = m.variety(crop, vraw);
    final date = _isoDate(_field(rec, 'arrival_date'));
    if (market == null || variety == null || date == null) continue;
    final d = DateTime.parse(date);
    if (d.isAfter(today) || today.difference(d).inDays > 7) continue; // future / stale

    final f = crop == 'rubber' ? 0.01 : 1.0; // data.gov.in quotes ₹/quintal
    double? conv(double? x) => x == null ? null : (x * f * 100).roundToDouble() / 100;
    final min = conv(_num(_field(rec, 'min_price')));
    final max = conv(_num(_field(rec, 'max_price')));
    final modal = conv(_num(_field(rec, 'modal_price')));
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
    final key = newestOnly ? '$market|$variety' : '$market|$variety|$date';
    final prev = out[key];
    if (prev == null || prev.date.compareTo(date) < 0) out[key] = row; // newest per market+variety
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

/// Rows → chart points per variety, one point per day (sorted, duplicates dropped).
Map<String, List<HistPoint>> historyByVariety(Iterable<PriceRow> rows) {
  final byKey = <String, Map<String, PriceRow>>{};
  for (final r in rows) {
    (byKey[r.variety] ??= {})[r.date] = r;
  }
  return {
    for (final e in byKey.entries)
      e.key: (e.value.values.toList()..sort((a, b) => a.date.compareTo(b.date)))
          .map((r) => HistPoint(DateTime.parse(r.date), r.min, r.max, r.modal))
          .toList(),
  };
}
