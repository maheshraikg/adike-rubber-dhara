import 'package:adike_dhara/data/diary.dart';
import 'package:adike_dhara/data/weather.dart';
import 'package:adike_dhara/models/models.dart';
import 'package:adike_dhara/ui/screens/compare_screen.dart';
import 'package:adike_dhara/ui/screens/detail_screen.dart';
import 'package:adike_dhara/ui/screens/share_card_screen.dart';
import 'package:adike_dhara/ui/screens/today_screen.dart';
import 'package:adike_dhara/ui/widgets/format.dart';
import 'package:flutter_test/flutter_test.dart';

PriceRow row(String market, double modal, {Trust trust = Trust.official, String date = '2026-09-29', String variety = 'rashi'}) =>
    PriceRow(crop: 'arecanut', variety: variety, labelKn: 'ರಾಶಿ', labelEn: 'Rashi', marketId: market, sourceId: 's${trust.index}',
        trust: trust, unit: 'INR/quintal', date: date, modal: modal, min: modal - 100, max: modal + 100);

void main() {
  test('inr uses Indian grouping', () {
    expect(inr(123456), '₹1,23,456');
    expect(inr(52500), '₹52,500');
    expect(inr(190.5), '₹190.50');
    expect(inr(null), '–');
  });

  test('drying rule', () {
    expect(classifyDrying(rainMm: 0, humidity: 70, cloud: 30), DryVerdict.good);
    expect(classifyDrying(rainMm: 1, humidity: 70, cloud: 30), DryVerdict.risky);
    expect(classifyDrying(rainMm: 0, humidity: 85, cloud: 30), DryVerdict.risky);
    expect(classifyDrying(rainMm: 2, humidity: 60, cloud: 10), DryVerdict.bad);
    expect(classifyDrying(rainMm: 0, humidity: 92, cloud: 10), DryVerdict.bad);
  });

  test('MET Norway parsing uses IST daytime only', () {
    Map<String, dynamic> e(String t, double hum, double rain, {double cloud = 20}) => {
          'time': t,
          'data': {
            'instant': {'details': {'air_temperature': 30, 'relative_humidity': hum, 'cloud_area_fraction': cloud}},
            'next_1_hours': {'details': {'precipitation_amount': rain}},
          },
        };
    final json = {
      'properties': {
        'timeseries': [
          e('2026-09-29T03:30:00Z', 70, 0), // 09:00 IST
          e('2026-09-29T06:30:00Z', 70, 0.2), // 12:00 IST
          e('2026-09-29T20:30:00Z', 99, 10), // 02:00 IST next day (night) - ignored
          e('2026-09-30T04:30:00Z', 95, 3), // 10:00 IST day 2
        ],
      },
    };
    final days = parseMetNorway(json, DateTime.utc(2026, 9, 29, 2));
    expect(days.length, 2);
    expect(days[0].verdict, DryVerdict.good);
    expect(days[0].rainMm, 0.2);
    expect(days[1].verdict, DryVerdict.bad);
  });

  test('http date parser', () {
    expect(HttpDateParser.parse('Tue, 29 Sep 2026 06:30:05 GMT'), DateTime.utc(2026, 9, 29, 6, 30, 5));
  });

  test('diary seasons, totals and CSV', () {
    expect(seasonOf(DateTime(2026, 6, 1)), '2026-27');
    expect(seasonOf(DateTime(2026, 5, 31)), '2025-26');
    expect(seasonOf(DateTime(2008, 7, 1)), '2008-09');
    final entries = [
      const DiaryEntry(id: '1', date: '2026-01-10', crop: 'arecanut', variety: 'Rashi', qtyKg: 100, amount: 52000, buyer: 'CAMPCO, Puttur'),
      const DiaryEntry(id: '2', date: '2026-02-10', crop: 'arecanut', variety: 'Rashi', qtyKg: 50, amount: 27000),
      const DiaryEntry(id: '3', date: '2026-07-01', crop: 'rubber', variety: 'RSS-4', qtyKg: 20, amount: 3800),
    ];
    final totals = seasonTotals(entries);
    final areca = totals.firstWhere((t) => t.crop == 'arecanut');
    expect(areca.season, '2025-26');
    expect(areca.qtyKg, 150);
    expect(areca.amount, 79000);
    final csv = diaryCsv(entries);
    expect(csv.split('\n').first, startsWith('date,season,crop'));
    expect(csv, contains('"CAMPCO, Puttur"'));
  });

  test('compare picks one row per market (trusted, latest) sorted by modal', () {
    final rows = [
      row('a', 50000),
      row('a', 51000, trust: Trust.partner),
      row('b', 53000, trust: Trust.partner),
      row('c', 49000, date: '2026-09-28'),
      row('c', 49500),
      row('d', 60000, variety: 'bette'),
    ];
    final out = compareRows(rows, 'arecanut', 'rashi');
    expect(out.map((r) => r.marketId), ['b', 'a', 'c']);
    expect(out[1].trust, Trust.official);
    expect(out[2].modal, 49500);
  });

  test('favourites first grouping', () {
    final g = groupByMarket([row('z', 1), row('a', 2), row('m', 3)], ['m'], (id) => id);
    expect(g.map((e) => e.key), ['m', 'a', 'z']);
  });

  test('share rows limited to favourites', () {
    final rows = [row('a', 1), row('b', 2), row('b', 3, trust: Trust.partner)];
    final out = shareRows(rows, ['b'], 'arecanut');
    expect(out.length, 1);
    expect(out.first.trust, Trust.official);
  });

  test('chart window and last-year compare', () {
    final pts = [
      for (var i = 0; i < 400; i++) HistPoint(DateTime(2026, 9, 29).subtract(Duration(days: i)), 1, 3, 2.0 + i),
    ];
    final w = windowed(pts, ChartRange.d7, DateTime(2026, 9, 29));
    expect(w.current.length, 8);
    expect(w.lastYear.length, 8);
    expect(w.lastYear.first.date.year, 2025);
  });
}
