import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'data/cached_http.dart';
import 'data/diary.dart';
import 'data/repository.dart';
import 'data/settings.dart';
import 'data/weather.dart';
import 'services/firebase_service.dart';
import 'ui/app.dart';
import 'ui/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['NotoSansKannada'], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  final prefs = await SharedPreferences.getInstance();
  final client = http.Client();
  final fb = FirebaseService();
  await fb.init();
  final state = AppState(
    settings: Settings(prefs),
    repo: PriceRepository(CachedHttp(client, prefs, headers: {'User-Agent': AppConfig.userAgent})),
    fb: fb,
    weather: WeatherService(client, prefs),
    diary: DiaryStore(prefs),
  );
  runApp(AdikeApp(state: state));
  state.refresh();
}
