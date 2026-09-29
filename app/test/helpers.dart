import 'dart:convert';

import 'package:adike_dhara/data/cached_http.dart';
import 'package:adike_dhara/data/diary.dart';
import 'package:adike_dhara/data/repository.dart';
import 'package:adike_dhara/data/settings.dart';
import 'package:adike_dhara/data/weather.dart';
import 'package:adike_dhara/services/firebase_service.dart';
import 'package:adike_dhara/ui/app_state.dart';
import 'package:adike_dhara/ui/widgets/format.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final today = todayIso();

Map<String, Object> sampleFiles() => {
      'latest.json': {
        'updatedAt': '${today}T17:30',
        'rows': [
          {'crop': 'arecanut', 'variety': 'rashi', 'varietyLabel_kn': 'ರಾಶಿ', 'varietyLabel_en': 'Rashi', 'marketId': 'shivamogga',
           'sourceId': 'datagov_mandi', 'trust': 'official', 'min': 50000, 'max': 53500, 'modal': 52500, 'unit': 'INR/quintal',
           'date': today, 'time': '11:30', 'change': 500, 'changePct': 0.96},
          {'crop': 'arecanut', 'variety': 'chali_new', 'varietyLabel_kn': 'ಹೊಸ ಚಾಲಿ', 'varietyLabel_en': 'New Chali', 'marketId': 'puttur',
           'sourceId': 'puttur_society', 'trust': 'partner', 'min': 42000, 'max': 46000, 'modal': 45000, 'unit': 'INR/quintal',
           'date': today, 'time': '12:10', 'change': -300, 'changePct': -0.66},
          {'crop': 'rubber', 'variety': 'rss4', 'varietyLabel_kn': 'ಆರ್‌ಎಸ್‌ಎಸ್-4', 'varietyLabel_en': 'RSS-4', 'marketId': 'kottayam',
           'sourceId': 'rubberboard_daily', 'trust': 'official', 'min': null, 'max': null, 'modal': 190, 'unit': 'INR/kg',
           'date': today, 'time': '17:30', 'change': null, 'changePct': null},
        ],
        'summary': {'kn': 'ಇಂದು ರಾಶಿ ಸ್ಥಿರ.', 'en': 'Rashi steady today.', 'date': today, 'source': 'template', 'evening': true},
      },
      'markets.json': [
        {'id': 'shivamogga', 'en': 'Shivamogga', 'kn': 'ಶಿವಮೊಗ್ಗ', 'district': 'Shivamogga', 'region': 'malnad', 'lat': 13.93, 'lon': 75.57},
        {'id': 'puttur', 'en': 'Puttur', 'kn': 'ಪುತ್ತೂರು', 'district': 'Dakshina Kannada', 'region': 'coastal', 'lat': 12.76, 'lon': 75.2},
        {'id': 'kottayam', 'en': 'Kottayam', 'kn': 'ಕೊಟ್ಟಾಯಂ', 'district': 'Kottayam', 'region': 'kerala', 'lat': 9.59, 'lon': 76.52},
      ],
      'varieties.json': [
        {'id': 'rashi', 'crop': 'arecanut', 'en': 'Rashi', 'kn': 'ರಾಶಿ'},
        {'id': 'chali_new', 'crop': 'arecanut', 'en': 'New Chali', 'kn': 'ಹೊಸ ಚಾಲಿ'},
        {'id': 'rss4', 'crop': 'rubber', 'en': 'RSS-4', 'kn': 'ಆರ್‌ಎಸ್‌ಎಸ್-4'},
      ],
      'sources.json': [
        {'id': 'datagov_mandi', 'type': 'official', 'name_en': 'APMC (data.gov.in)', 'name_kn': 'ಎಪಿಎಂಸಿ', 'score': 1.0},
        {'id': 'puttur_society', 'type': 'partner', 'name_en': 'Puttur Society', 'name_kn': 'ಪುತ್ತೂರು ಸಂಘ', 'score': 0.8},
        {'id': 'rubberboard_daily', 'type': 'official', 'name_en': 'Rubber Board', 'name_kn': 'ರಬ್ಬರ್ ಮಂಡಳಿ', 'score': 1.0},
      ],
    };

MockClient mockClient({bool fail = false}) {
  final files = sampleFiles();
  return MockClient((req) async {
    if (fail) throw http.ClientException('offline');
    final name = req.url.pathSegments.last;
    final body = files[name];
    if (body == null) return http.Response('not found', 404);
    return http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'etag': '"v1"', 'content-type': 'application/json'});
  });
}

Future<AppState> makeState({Map<String, Object> prefs = const {}, http.Client? client, bool reset = true}) async {
  if (reset) SharedPreferences.setMockInitialValues({'onboarded': true, 'favMarkets': ['puttur'], ...prefs});
  final p = await SharedPreferences.getInstance();
  final c = client ?? mockClient();
  return AppState(
    settings: Settings(p),
    repo: PriceRepository(CachedHttp(c, p), baseUrl: 'https://example.test/'),
    fb: FirebaseService(),
    weather: WeatherService(c, p),
    diary: DiaryStore(p),
  );
}
