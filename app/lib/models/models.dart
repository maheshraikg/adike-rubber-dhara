/// Data models mirroring the JSON published by the pipeline (see docs/ARCHITECTURE.md).
library;

double? _d(dynamic v) => v == null ? null : (v as num).toDouble();

enum Trust { official, partner, trader }

Trust trustFrom(String? s) => switch (s) {
      'partner' => Trust.partner,
      'trader' => Trust.trader,
      _ => Trust.official,
    };

class PriceRow {
  final String crop, variety, labelKn, labelEn, marketId, sourceId, unit, date, time;
  final Trust trust;
  final double? min, max, modal, change, changePct;

  const PriceRow({
    required this.crop,
    required this.variety,
    required this.labelKn,
    required this.labelEn,
    required this.marketId,
    required this.sourceId,
    required this.trust,
    required this.unit,
    required this.date,
    this.time = '',
    this.min,
    this.max,
    this.modal,
    this.change,
    this.changePct,
  });

  factory PriceRow.fromJson(Map<String, dynamic> j) => PriceRow(
        crop: j['crop'] as String,
        variety: j['variety'] as String,
        labelKn: (j['varietyLabel_kn'] ?? j['variety']) as String,
        labelEn: (j['varietyLabel_en'] ?? j['variety']) as String,
        marketId: j['marketId'] as String,
        sourceId: j['sourceId'] as String,
        trust: trustFrom(j['trust'] as String?),
        unit: (j['unit'] ?? '') as String,
        date: j['date'] as String,
        time: (j['time'] ?? '') as String,
        min: _d(j['min']),
        max: _d(j['max']),
        modal: _d(j['modal']),
        change: _d(j['change']),
        changePct: _d(j['changePct']),
      );

  /// Idempotent key used by the pipeline: date_source_market_crop_variety.
  String get key => '${date}_${sourceId}_${marketId}_${crop}_$variety';

  String label(bool kannada) => kannada ? labelKn : labelEn;
}

class Summary {
  final String kn, en, date;
  final bool fromAi;
  const Summary({required this.kn, required this.en, required this.date, this.fromAi = false});

  static Summary? fromJson(dynamic j) {
    if (j is! Map) return null;
    return Summary(
      kn: (j['kn'] ?? '') as String,
      en: (j['en'] ?? '') as String,
      date: (j['date'] ?? '') as String,
      fromAi: j['source'] == 'ai',
    );
  }
}

class Latest {
  final String updatedAt;
  final List<PriceRow> rows;
  final Summary? summary;
  final bool sample;
  const Latest({required this.updatedAt, required this.rows, this.summary, this.sample = false});

  factory Latest.fromJson(Map<String, dynamic> j) => Latest(
        updatedAt: (j['updatedAt'] ?? '') as String,
        rows: ((j['rows'] ?? []) as List).map((e) => PriceRow.fromJson(e as Map<String, dynamic>)).toList(),
        summary: Summary.fromJson(j['summary']),
        sample: j['sample'] == true,
      );

  static const empty = Latest(updatedAt: '', rows: []);
}

class Market {
  final String id, en, kn, district, region;
  final double? lat, lon;
  const Market({required this.id, required this.en, required this.kn, this.district = '', this.region = 'other', this.lat, this.lon});

  factory Market.fromJson(Map<String, dynamic> j) => Market(
        id: j['id'] as String,
        en: j['en'] as String,
        kn: j['kn'] as String,
        district: (j['district'] ?? '') as String,
        region: (j['region'] ?? 'other') as String,
        lat: _d(j['lat']),
        lon: _d(j['lon']),
      );

  String name(bool kannada) => kannada ? kn : en;
}

class Variety {
  final String id, crop, en, kn;
  const Variety({required this.id, required this.crop, required this.en, required this.kn});
  factory Variety.fromJson(Map<String, dynamic> j) =>
      Variety(id: j['id'] as String, crop: j['crop'] as String, en: j['en'] as String, kn: j['kn'] as String);
  String name(bool kannada) => kannada ? kn : en;
}

class SourceProfile {
  final String? address, timings, phone;
  final double? lat, lon;
  const SourceProfile({this.address, this.timings, this.phone, this.lat, this.lon});
  factory SourceProfile.fromJson(dynamic j) {
    if (j is! Map) return const SourceProfile();
    return SourceProfile(
      address: j['address'] as String?,
      timings: j['timings'] as String?,
      phone: j['phone'] as String?,
      lat: _d(j['lat']),
      lon: _d(j['lon']),
    );
  }
  bool get isEmpty => address == null && timings == null && phone == null && lat == null;
}

class Source {
  final String id, nameEn, nameKn, url, kind;
  final Trust trust;
  final bool enabled;
  final double score;
  final SourceProfile profile;
  const Source({
    required this.id,
    required this.nameEn,
    required this.nameKn,
    required this.trust,
    this.url = '',
    this.kind = '',
    this.enabled = true,
    this.score = 0.5,
    this.profile = const SourceProfile(),
  });

  factory Source.fromJson(Map<String, dynamic> j) => Source(
        id: j['id'] as String,
        nameEn: (j['name_en'] ?? j['id']) as String,
        nameKn: (j['name_kn'] ?? j['name_en'] ?? j['id']) as String,
        trust: trustFrom(j['type'] as String?),
        url: (j['url'] ?? '') as String,
        kind: (j['kind'] ?? '') as String,
        enabled: j['enabled'] != false,
        score: _d(j['score']) ?? 0.5,
        profile: SourceProfile.fromJson(j['profile']),
      );

  String name(bool kannada) => kannada ? nameKn : nameEn;
}

class HistPoint {
  final DateTime date;
  final double? min, max, modal;
  const HistPoint(this.date, this.min, this.max, this.modal);
}

class History {
  /// key: "sourceId|variety"
  final Map<String, List<HistPoint>> series;
  const History(this.series);

  factory History.fromJson(Map<String, dynamic> j) {
    final out = <String, List<HistPoint>>{};
    ((j['series'] ?? {}) as Map).forEach((k, v) {
      out[k as String] = (v as List)
          .map((p) => HistPoint(DateTime.parse(p[0] as String), _d(p[1]), _d(p[2]), _d(p[3])))
          .toList();
    });
    return History(out);
  }

  List<HistPoint> of(String sourceId, String variety) => series['$sourceId|$variety'] ?? const [];

  static const empty = History({});
}
