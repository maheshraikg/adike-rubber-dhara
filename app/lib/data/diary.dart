import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DiaryEntry {
  final String id, date, crop, variety, buyer, note;
  final double qtyKg, amount;
  const DiaryEntry({
    required this.id,
    required this.date,
    required this.crop,
    required this.variety,
    required this.qtyKg,
    required this.amount,
    this.buyer = '',
    this.note = '',
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'date': date, 'crop': crop, 'variety': variety, 'qtyKg': qtyKg, 'amount': amount, 'buyer': buyer, 'note': note};

  factory DiaryEntry.fromJson(Map<String, dynamic> j) => DiaryEntry(
        id: j['id'] as String,
        date: j['date'] as String,
        crop: j['crop'] as String,
        variety: (j['variety'] ?? '') as String,
        qtyKg: (j['qtyKg'] as num).toDouble(),
        amount: (j['amount'] as num).toDouble(),
        buyer: (j['buyer'] ?? '') as String,
        note: (j['note'] ?? '') as String,
      );
}

/// Season runs June → May (e.g. "2025-26" = 1 Jun 2025 – 31 May 2026).
String seasonOf(DateTime d) {
  final start = d.month >= 6 ? d.year : d.year - 1;
  return '$start-${(start + 1) % 100}'.replaceFirstMapped(RegExp(r'-(\d)$'), (m) => '-0${m[1]}');
}

class SeasonTotal {
  final String season, crop;
  final double qtyKg, amount;
  const SeasonTotal(this.season, this.crop, this.qtyKg, this.amount);
  double get avgPerKg => qtyKg == 0 ? 0 : amount / qtyKg;
}

List<SeasonTotal> seasonTotals(List<DiaryEntry> entries) {
  final map = <String, List<double>>{};
  for (final e in entries) {
    final k = '${seasonOf(DateTime.parse(e.date))}|${e.crop}';
    final t = map.putIfAbsent(k, () => [0, 0]);
    t[0] += e.qtyKg;
    t[1] += e.amount;
  }
  final out = map.entries.map((e) {
    final p = e.key.split('|');
    return SeasonTotal(p[0], p[1], e.value[0], e.value[1]);
  }).toList()
    ..sort((a, b) => b.season.compareTo(a.season));
  return out;
}

String _csvCell(String s) => (s.contains(',') || s.contains('"') || s.contains('\n')) ? '"${s.replaceAll('"', '""')}"' : s;

String diaryCsv(List<DiaryEntry> entries) {
  final b = StringBuffer('date,season,crop,variety,quantity_kg,amount_inr,rate_per_kg,buyer,note\n');
  for (final e in entries) {
    final rate = e.qtyKg == 0 ? 0 : e.amount / e.qtyKg;
    b.writeln([
      e.date,
      seasonOf(DateTime.parse(e.date)),
      e.crop,
      _csvCell(e.variety),
      e.qtyKg.toStringAsFixed(2),
      e.amount.toStringAsFixed(2),
      rate.toStringAsFixed(2),
      _csvCell(e.buyer),
      _csvCell(e.note),
    ].join(','));
  }
  return b.toString();
}

/// On-device only. Never uploaded.
class DiaryStore {
  static const _key = 'diary.v1';
  final SharedPreferences prefs;
  DiaryStore(this.prefs);

  List<DiaryEntry> all() {
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).map((e) => DiaryEntry.fromJson(e as Map<String, dynamic>)).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> _save(List<DiaryEntry> list) => prefs.setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));

  Future<void> add(DiaryEntry e) => _save([...all(), e]);

  Future<void> remove(String id) => _save(all().where((e) => e.id != id).toList());
}
