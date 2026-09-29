import 'dart:async';

import 'package:flutter/material.dart';

import '../data/diary.dart';
import '../data/repository.dart';
import '../data/settings.dart';
import '../data/weather.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';

class AppState extends ChangeNotifier {
  final Settings settings;
  final PriceRepository repo;
  final FirebaseService fb;
  final WeatherService weather;
  final DiaryStore diary;

  AppState({required this.settings, required this.repo, required this.fb, required this.weather, required this.diary}) {
    data = repo.cachedOnly();
    crop = settings.crop;
  }

  PriceData? data;
  bool loading = false;
  Object? error;
  late String crop;

  bool get kn => settings.language == 'kn';
  Locale get locale => Locale(settings.language);
  List<String> get favourites => settings.favourites;

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      data = await repo.load();
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setCrop(String c) async {
    crop = c;
    await settings.setCrop(c);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    await settings.setLanguage(lang);
    notifyListeners();
  }

  Future<void> setFavourites(List<String> ids) async {
    await settings.setFavourites(ids);
    await settings.setOnboarded();
    notifyListeners();
  }

  Future<void> setDailySummary(bool on) async {
    await settings.setDailySummary(on);
    notifyListeners();
    try {
      await fb.setTopic('daily_summary', on);
    } catch (_) {}
  }

  // ---- lookups ----
  Market? market(String id) => data?.markets[id];
  String marketName(String id) => market(id)?.name(kn) ?? id;
  Source? source(String id) => data?.sources[id];
  String sourceName(String id) => source(id)?.name(kn) ?? id;
  List<PriceRow> get rows => data?.latest.rows ?? const [];
  List<PriceRow> rowsFor(String crop) => rows.where((r) => r.crop == crop).toList();

  void notify() => notifyListeners();
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
