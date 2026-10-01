import 'dart:convert';
import 'dart:io';

import 'package:adike_dhara/data/cached_http.dart';
import 'package:adike_dhara/data/mandi_live.dart';
import 'package:adike_dhara/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The real lists the pipeline publishes (with aliases).
final markets = {
  for (final m in jsonDecode(File('../data/markets.json').readAsStringSync()) as List)
    (m['id'] as String): Market.fromJson(m as Map<String, dynamic>)
};
final varieties = {
  for (final v in jsonDecode(File('../data/varieties.json').readAsStringSync()) as List)
    (v['id'] as String): Variety.fromJson(v as Map<String, dynamic>)
};
final matcher = NameMatcher(markets.values, varieties.values);
final now = DateTime(2026, 9, 30, 12);

Map<String, dynamic> rec(String market, String variety, String min, String max, String modal,
        {String date = '29/09/2026', String grade = 'FAQ'}) =>
    {'state': 'Karnataka', 'market': market, 'variety': variety, 'grade': grade, 'arrival_date': date,
     'min_price': min, 'max_price': max, 'modal_price': modal};

void main() {
  test('matches markets and varieties by alias, keeps printed figures', () {
    final rows = parseRecords([rec('Shimoga', 'Rashi', '50000', '53500', '52500')], 'arecanut', matcher, now: now);
    expect(rows, hasLength(1));
    final r = rows.single;
    expect((r.marketId, r.variety, r.min, r.max, r.modal, r.date, r.unit),
        ('shivamogga', 'rashi', 50000.0, 53500.0, 52500.0, '2026-09-29', 'INR/quintal'));
    expect((r.sourceId, r.trust), (MandiLive.sourceId, Trust.official));
  });

  test('drops rows that fail the checks instead of guessing', () {
    final rows = parseRecords([
      rec('Sagar', 'Bette', '57000', '54000', '55500'), // min > max
      rec('Puttur', 'New Variety', '42000', '46000', ''), // no modal
      rec('Mudigere', 'Rashi', '48000', '51000', '50000'), // unknown market
      rec('Shimoga', 'Mystery', '48000', '51000', '50000'), // unknown variety
      rec('Shimoga', 'Rashi', '500', '600', '550'), // out of range
      rec('Shimoga', 'Rashi', '50000', '53500', '60000'), // modal above max
      rec('Shimoga', 'Rashi', '50000', '53500', '52500', date: '01/10/2026'), // future
      rec('Shimoga', 'Rashi', '50000', '53500', '52500', date: '01/09/2026'), // stale
    ], 'arecanut', matcher, now: now);
    expect(rows, isEmpty);
  });

  test('rubber ₹/quintal becomes ₹/kg; newest row per market and variety wins', () {
    final rows = parseRecords([
      {'market': 'Kottayam', 'variety': 'RSS-4', 'arrival_date': '28/09/2026', 'min_price': '27000', 'max_price': '28000', 'modal_price': '27500'},
      {'market': 'Kottayam', 'variety': 'RSS-4', 'arrival_date': '29/09/2026', 'min_price': '27500', 'max_price': '28500', 'modal_price': '28000'},
    ], 'rubber', matcher, now: now);
    expect(rows.single.modal, 280.0);
    expect(rows.single.unit, 'INR/kg');
    expect(rows.single.date, '2026-09-29');
  });

  test('merge adds only rows newer than what is published', () {
    PriceRow row(String src, String market, String date) => PriceRow(
        crop: 'arecanut', variety: 'rashi', labelKn: 'ರಾಶಿ', labelEn: 'Rashi', marketId: market,
        sourceId: src, trust: Trust.official, unit: 'INR/quintal', date: date, modal: 50000);
    final published = [row('datagov_mandi', 'shivamogga', '2026-09-29')];
    final live = [row(MandiLive.sourceId, 'shivamogga', '2026-09-29'), row(MandiLive.sourceId, 'sagar', '2026-09-29'),
                  row(MandiLive.sourceId, 'shivamogga', '2026-09-30')];
    final merged = mergeLive(published, live);
    expect(merged.map((r) => '${r.sourceId}/${r.marketId}/${r.date}'), [
      'datagov_mandi/shivamogga/2026-09-29',
      '${MandiLive.sourceId}/sagar/2026-09-29',
      '${MandiLive.sourceId}/shivamogga/2026-09-30',
    ]);
  });

  test('fetch pages in tens with the public sample key; failures are silent', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final seen = <Uri>[];
    final today = DateTime.now();
    final d = '${today.day.toString().padLeft(2, '0')}/${today.month.toString().padLeft(2, '0')}/${today.year}';
    final client = MockClient((req) async {
      seen.add(req.url);
      final qp = req.url.queryParameters;
      if (qp['filters[commodity.keyword]'] != 'Arecanut(Betelnut/Supari)') throw http.ClientException('down');
      final off = int.parse(qp['offset']!);
      final all = [for (final m in ['Shimoga', 'Sagar', 'Sirsi', 'Puttur', 'Tirthahalli', 'Yellapur', 'Kumta',
                                     'Honnavar', 'Siddapur', 'Koppa', 'Sringeri', 'Bantwal'])
                   rec(m, 'Rashi', '50000', '53500', '52500', date: d)];
      final page = all.skip(off).take(10).toList();
      return http.Response(jsonEncode({'total': all.length, 'records': page}), 200);
    });
    final rows = await MandiLive(CachedHttp(client, p)).fetch(markets, varieties);
    final arecanutCalls = seen.where((u) => u.queryParameters['filters[commodity.keyword]']?.startsWith('Arecanut') ?? false);
    expect(arecanutCalls.map((u) => u.queryParameters['offset']), ['0', '10']);
    expect(arecanutCalls.every((u) => u.queryParameters['api-key'] == MandiLive.sampleKey && u.queryParameters['limit'] == '10'), isTrue);
    expect(rows.where((r) => r.crop == 'arecanut').length, greaterThanOrEqualTo(10));
  });

  test('7-day history: history dataset fields, one point per day for the market', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final today = DateTime(2026, 9, 30);
    String dmy(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final client = MockClient((req) async {
      final qp = req.url.queryParameters;
      if (!req.url.path.contains('35985678')) return http.Response(jsonEncode({'total': 0, 'records': []}), 200);
      final date = qp['filters[Arrival_Date]'];
      if (date == null || qp['filters[Commodity]'] != 'Arecanut(Betelnut/Supari)') {
        return http.Response(jsonEncode({'total': 0, 'records': []}), 200);
      }
      final back = [for (var i = 0; i < 7; i++) dmy(today.subtract(Duration(days: i)))].indexOf(date);
      if (back < 0 || back == 1) return http.Response(jsonEncode({'total': 0, 'records': []}), 200); // a holiday
      final modal = 52000 + back * 100;
      final recs = [
        {'State': 'Karnataka', 'Market': 'Shimoga', 'Commodity': 'Arecanut(Betelnut/Supari)', 'Variety': 'Rashi',
         'Grade': 'FAQ', 'Arrival_Date': date, 'Min_x0020_Price': '${modal - 1000}', 'Max_x0020_Price': '${modal + 1000}',
         'Modal_x0020_Price': '$modal'},
        {'State': 'Karnataka', 'Market': 'Sagar', 'Commodity': 'Arecanut(Betelnut/Supari)', 'Variety': 'Rashi',
         'Grade': 'FAQ', 'Arrival_Date': date, 'Min_x0020_Price': '50000', 'Max_x0020_Price': '52000',
         'Modal_x0020_Price': '51000'},
      ];
      return http.Response(jsonEncode({'total': recs.length, 'records': recs}), 200);
    });
    final h = await MandiLive(CachedHttp(client, p)).history('arecanut', 'shivamogga', markets, varieties, now: today);
    final pts = h['rashi']!;
    expect(pts, hasLength(6)); // 7 days minus the holiday; Sagar rows excluded
    expect(pts.first.date, today.subtract(const Duration(days: 6)));
    expect(pts.last.date, today);
    expect(pts.last.modal, 52000.0);
    expect(pts.first.min, 51600.0); // 6 days back: modal 52600, min 51600
  });
}
