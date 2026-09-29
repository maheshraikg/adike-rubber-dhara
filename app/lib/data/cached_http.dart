import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CachedBody {
  final String body;
  final DateTime fetchedAt;
  final bool fromCache;
  final bool offline;
  const CachedBody(this.body, this.fetchedAt, {this.fromCache = false, this.offline = false});
}

/// GET with ETag / If-None-Match and an offline copy in SharedPreferences.
/// GitHub Pages returns ETags, so an unchanged file costs a 304 with no body.
class CachedHttp {
  final http.Client client;
  final SharedPreferences prefs;
  final Map<String, String> headers;
  CachedHttp(this.client, this.prefs, {this.headers = const {}});

  String _k(String url, String part) => 'http:$part:$url';

  CachedBody? cached(String url) {
    final body = prefs.getString(_k(url, 'body'));
    if (body == null) return null;
    final at = DateTime.tryParse(prefs.getString(_k(url, 'at')) ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
    return CachedBody(body, at, fromCache: true);
  }

  /// [maxAge]: skip the network entirely when the cached copy is younger.
  Future<CachedBody> get(String url, {Duration maxAge = Duration.zero, Duration timeout = const Duration(seconds: 15)}) async {
    final old = cached(url);
    if (old != null && DateTime.now().difference(old.fetchedAt) < maxAge) return old;
    final h = Map<String, String>.from(headers);
    final etag = prefs.getString(_k(url, 'etag'));
    if (old != null && etag != null) h['If-None-Match'] = etag;
    try {
      final r = await client.get(Uri.parse(url), headers: h).timeout(timeout);
      final now = DateTime.now();
      if (r.statusCode == 304 && old != null) {
        await prefs.setString(_k(url, 'at'), now.toIso8601String());
        return CachedBody(old.body, now, fromCache: true);
      }
      if (r.statusCode == 200) {
        final body = r.body;
        await prefs.setString(_k(url, 'body'), body);
        await prefs.setString(_k(url, 'at'), now.toIso8601String());
        final newTag = r.headers['etag'];
        if (newTag != null) await prefs.setString(_k(url, 'etag'), newTag);
        return CachedBody(body, now);
      }
      throw http.ClientException('HTTP ${r.statusCode}', Uri.parse(url));
    } catch (e) {
      if (old != null) return CachedBody(old.body, old.fetchedAt, fromCache: true, offline: true);
      rethrow;
    }
  }
}
