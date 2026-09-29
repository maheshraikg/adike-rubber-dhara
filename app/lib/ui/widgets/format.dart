import 'package:intl/intl.dart';

import '../../l10n/gen/app_localizations.dart';

final _inr0 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _inr2 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _num0 = NumberFormat.decimalPattern('en_IN');

/// ₹1,23,456 (Indian grouping). Shows paise only when present.
String inr(num? v) {
  if (v == null) return '–';
  final frac = (v - v.truncate()).abs();
  return frac > 0.004 ? _inr2.format(v) : _inr0.format(v);
}

String plainNum(num v) => _num0.format(v);

String unitLabel(String crop, AppLocalizations t) => crop == 'rubber' ? t.unitKg : t.unitQuintal;

String cropLabel(String crop, AppLocalizations t) => crop == 'rubber' ? t.cropRubber : t.cropArecanut;

/// "29 Sep" / "29 ಸೆಪ್ಟೆಂ" style short date.
String shortDate(String iso, String locale) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return DateFormat('d MMM', locale).format(d);
}

String todayIso() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  return DateFormat('yyyy-MM-dd').format(now);
}

double? parseInput(String s) => double.tryParse(s.replaceAll(',', '').trim());
