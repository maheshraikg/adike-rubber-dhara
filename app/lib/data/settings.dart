import 'package:shared_preferences/shared_preferences.dart';

/// Per-device settings (no account needed).
class Settings {
  final SharedPreferences prefs;
  Settings(this.prefs);

  String get language => prefs.getString('lang') ?? 'kn';
  Future<void> setLanguage(String v) => prefs.setString('lang', v);

  bool get onboarded => prefs.getBool('onboarded') ?? false;
  Future<void> setOnboarded() => prefs.setBool('onboarded', true);

  List<String> get favourites => prefs.getStringList('favMarkets') ?? const [];
  Future<void> setFavourites(List<String> v) => prefs.setStringList('favMarkets', v);

  bool get dailySummary => prefs.getBool('dailySummary') ?? true;
  Future<void> setDailySummary(bool v) => prefs.setBool('dailySummary', v);

  String get crop => prefs.getString('crop') ?? 'arecanut';
  Future<void> setCrop(String v) => prefs.setString('crop', v);

  String? get weatherMarket => prefs.getString('weatherMarket');
  Future<void> setWeatherMarket(String v) => prefs.setString('weatherMarket', v);
}
