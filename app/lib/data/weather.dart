import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

enum DryVerdict { good, risky, bad }

class DayWeather {
  final DateTime day;
  final double rainMm, humidity, cloud, maxTemp;
  final DryVerdict verdict;
  const DayWeather(this.day, this.rainMm, this.humidity, this.cloud, this.maxTemp, this.verdict);
}

/// Drying rule (documented in the app): daytime 08:00–17:00 IST.
/// Good: rain < 0.5 mm AND humidity < 80% AND cloud < 70%.
/// Bad: rain ≥ 2 mm OR humidity ≥ 90%. Otherwise risky.
DryVerdict classifyDrying({required double rainMm, required double humidity, required double cloud}) {
  if (rainMm >= 2 || humidity >= 90) return DryVerdict.bad;
  if (rainMm < 0.5 && humidity < 80 && cloud < 70) return DryVerdict.good;
  return DryVerdict.risky;
}

const _ist = Duration(hours: 5, minutes: 30);

/// Parse MET Norway locationforecast/2.0/compact into up to [days] daytime summaries.
List<DayWeather> parseMetNorway(Map<String, dynamic> json, DateTime nowUtc, {int days = 3}) {
  final series = (json['properties']?['timeseries'] ?? []) as List;
  final todayIst = nowUtc.add(_ist);
  final start = DateTime.utc(todayIst.year, todayIst.month, todayIst.day);
  final out = <DayWeather>[];
  for (var d = 0; d < days; d++) {
    final day = start.add(Duration(days: d));
    double rain = 0, humSum = 0, cloudSum = 0, maxT = -100;
    var n = 0;
    for (final e in series) {
      final t = DateTime.parse(e['time'] as String).toUtc().add(_ist); // IST wall-clock as UTC
      if (t.year != day.year || t.month != day.month || t.day != day.day) continue;
      if (t.hour < 8 || t.hour >= 17) continue;
      final data = e['data'] as Map<String, dynamic>;
      final inst = (data['instant']?['details'] ?? {}) as Map<String, dynamic>;
      humSum += (inst['relative_humidity'] as num? ?? 0).toDouble();
      cloudSum += (inst['cloud_area_fraction'] as num? ?? 0).toDouble();
      final temp = (inst['air_temperature'] as num?)?.toDouble();
      if (temp != null && temp > maxT) maxT = temp;
      n++;
      final one = data['next_1_hours']?['details']?['precipitation_amount'] as num?;
      final six = data['next_6_hours']?['details']?['precipitation_amount'] as num?;
      rain += (one ?? six ?? 0).toDouble();
    }
    if (n == 0) continue;
    final hum = humSum / n, cloud = cloudSum / n;
    out.add(DayWeather(day, double.parse(rain.toStringAsFixed(1)), hum.roundToDouble(), cloud.roundToDouble(), maxT,
        classifyDrying(rainMm: rain, humidity: hum, cloud: cloud)));
  }
  return out;
}

/// MET Norway client: identifying User-Agent, lat/lon rounded to 2 decimals,
/// cached until the Expires header (their terms of service).
class WeatherService {
  final http.Client client;
  final SharedPreferences prefs;
  WeatherService(this.client, this.prefs);

  Future<List<DayWeather>> forecast(double lat, double lon) async {
    final la = lat.toStringAsFixed(2), lo = lon.toStringAsFixed(2);
    final key = 'met:$la,$lo';
    final expires = DateTime.tryParse(prefs.getString('$key:exp') ?? '');
    String? body = prefs.getString('$key:body');
    if (body == null || expires == null || DateTime.now().toUtc().isAfter(expires)) {
      final uri = Uri.parse('https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=$la&lon=$lo');
      final headers = {'User-Agent': AppConfig.userAgent};
      final lm = prefs.getString('$key:lm');
      if (body != null && lm != null) headers['If-Modified-Since'] = lm;
      try {
        final r = await client.get(uri, headers: headers).timeout(const Duration(seconds: 15));
        if (r.statusCode == 200) {
          body = r.body;
          await prefs.setString('$key:body', body);
          if (r.headers['last-modified'] != null) await prefs.setString('$key:lm', r.headers['last-modified']!);
        }
        if (r.statusCode == 200 || r.statusCode == 304) {
          final exp = _parseHttpDate(r.headers['expires']) ?? DateTime.now().toUtc().add(const Duration(minutes: 30));
          await prefs.setString('$key:exp', exp.toIso8601String());
        } else if (body == null) {
          throw http.ClientException('HTTP ${r.statusCode}', uri);
        }
      } catch (_) {
        if (body == null) rethrow;
      }
    }
    return parseMetNorway(jsonDecode(body!) as Map<String, dynamic>, DateTime.now().toUtc());
  }

  static DateTime? _parseHttpDate(String? s) {
    if (s == null) return null;
    try {
      return HttpDateParser.parse(s);
    } catch (_) {
      return null;
    }
  }
}

/// Minimal RFC 1123 date parser ("Tue, 29 Sep 2026 06:30:00 GMT") without dart:io (works on web).
class HttpDateParser {
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static DateTime parse(String s) {
    final p = s.split(RegExp(r'[ ,:]+')).where((x) => x.isNotEmpty).toList();
    // [Tue, 29, Sep, 2026, 06, 30, 00, GMT]
    return DateTime.utc(int.parse(p[3]), _months.indexOf(p[2]) + 1, int.parse(p[1]), int.parse(p[4]), int.parse(p[5]),
        int.parse(p[6]));
  }
}
