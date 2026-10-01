// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Adike Rubber Rates';

  @override
  String get navToday => 'Today';

  @override
  String get navCompare => 'Compare';

  @override
  String get navCalculator => 'Calculator';

  @override
  String get navDiary => 'Diary';

  @override
  String get navMore => 'More';

  @override
  String get cropArecanut => 'Arecanut';

  @override
  String get cropRubber => 'Rubber';

  @override
  String get unitQuintal => '₹/quintal';

  @override
  String get unitKg => '₹/kg';

  @override
  String get badgeOfficial => 'Official';

  @override
  String get badgePartner => 'Partner';

  @override
  String get badgeTrader => 'Trader';

  @override
  String get modal => 'Modal';

  @override
  String get minLabel => 'Min';

  @override
  String get maxLabel => 'Max';

  @override
  String lastUpdated(String time) {
    return 'Last updated: $time';
  }

  @override
  String offlineBanner(String time) {
    return 'Offline — showing saved rates from $time';
  }

  @override
  String get loadError =>
      'Could not load rates. Check internet and pull to refresh.';

  @override
  String get noData => 'No rates available';

  @override
  String get myMarkets => 'My markets';

  @override
  String get otherMarkets => 'Other markets';

  @override
  String get summaryTitle => 'Today\'s summary';

  @override
  String get summaryNote =>
      'Auto-written only from published rates. Not advice.';

  @override
  String get sampleData => 'SAMPLE data — not real prices';

  @override
  String get pickMarketsTitle => 'Choose your markets';

  @override
  String get pickMarketsHint =>
      'Your markets are shown first. You can change them later in Settings.';

  @override
  String get continueLabel => 'Continue';

  @override
  String get regionCoastal => 'Coastal';

  @override
  String get regionMalnad => 'Malnad';

  @override
  String get regionOther => 'Other Karnataka';

  @override
  String get regionKerala => 'Kerala';

  @override
  String get range7d => '7D';

  @override
  String get range1m => '1M';

  @override
  String get range6m => '6M';

  @override
  String get range1y => '1Y';

  @override
  String get seasonCompare => 'Same period last year';

  @override
  String get thisYear => 'This year';

  @override
  String get recentDays => 'Recent days';

  @override
  String get allSources => 'All sources';

  @override
  String get setAlert => 'Set alert';

  @override
  String get share => 'Share';

  @override
  String get reportWrong => 'Report wrong rate';

  @override
  String get dateLabel => 'Date';

  @override
  String get noHistory => 'No history yet';

  @override
  String get compareTitle => 'Compare markets';

  @override
  String get variety => 'Variety';

  @override
  String get market => 'Market';

  @override
  String get alertsTitle => 'Price alerts';

  @override
  String get alertAbove => 'Goes above';

  @override
  String get alertBelow => 'Falls below';

  @override
  String get alertValue => 'Price (₹)';

  @override
  String get alertCreate => 'Create alert';

  @override
  String get alertNone => 'No alerts yet. Open a rate and tap “Set alert”.';

  @override
  String get alertSaved =>
      'Alert saved. You will get a notification once a day at most.';

  @override
  String alertLine(
    String variety,
    String market,
    String condition,
    String value,
  ) {
    return '$variety · $market: $condition $value';
  }

  @override
  String get needsOnline =>
      'This needs internet and the app\'s online services.';

  @override
  String get notConfigured =>
      'Online services are not configured in this build.';

  @override
  String errorGeneric(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get retry => 'Retry';

  @override
  String get calcTitle => 'Sale calculator';

  @override
  String get quantity => 'Quantity';

  @override
  String get unitKgShort => 'kg';

  @override
  String get unitQuintalShort => 'quintal';

  @override
  String get unitBags => 'bags';

  @override
  String get bagWeight => 'Weight per bag (kg)';

  @override
  String get rate => 'Rate';

  @override
  String get useTodayRate => 'Use today\'s rate';

  @override
  String get commissionPct => 'Commission %';

  @override
  String get hamali => 'Hamali (₹)';

  @override
  String get transport => 'Transport (₹)';

  @override
  String get gross => 'Gross amount';

  @override
  String get deductions => 'Deductions';

  @override
  String get net => 'Net amount';

  @override
  String totalKg(String kg) {
    return 'Total weight: $kg kg';
  }

  @override
  String get diaryTitle => 'Sales diary';

  @override
  String get diaryAdd => 'Add sale';

  @override
  String get diaryEmpty => 'No sales recorded yet.';

  @override
  String get diaryBuyer => 'Buyer / society';

  @override
  String get diaryNote => 'Note';

  @override
  String get diaryAmount => 'Amount received (₹)';

  @override
  String get diaryQtyKg => 'Quantity (kg)';

  @override
  String seasonTotal(String season) {
    return 'Season $season total';
  }

  @override
  String get exportCsv => 'Export CSV';

  @override
  String get diaryPrivate => 'Your diary stays only on this phone.';

  @override
  String get weatherTitle => 'Drying weather';

  @override
  String get dryGood => 'Good drying day';

  @override
  String get dryRisky => 'Risky';

  @override
  String get dryBad => 'Bad drying day';

  @override
  String get dryRule =>
      'Daytime 8 am–5 pm. Good: rain < 0.5 mm, humidity < 80%, cloud < 70%. Bad: rain ≥ 2 mm or humidity ≥ 90%. Otherwise risky.';

  @override
  String weatherStats(String rain, String hum, String cloud) {
    return 'Rain $rain mm · Humidity $hum% · Cloud $cloud%';
  }

  @override
  String get weatherAttribution =>
      'Weather data: MET Norway (api.met.no), CC BY 4.0';

  @override
  String get weatherPlace => 'Place';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get shareCardTitle => 'Share card';

  @override
  String get shareCardHint =>
      'Shows today\'s rates for your markets. Share it on WhatsApp.';

  @override
  String get shareNow => 'Share image';

  @override
  String get settingsTitle => 'Settings & about';

  @override
  String get language => 'Language';

  @override
  String get notifications => 'Notifications';

  @override
  String get dailySummaryNotif => 'Daily evening summary';

  @override
  String get dataSources => 'Data sources';

  @override
  String get disclaimer =>
      'Rates are indicative only; confirm with the buyer before selling.';

  @override
  String get privacyNote =>
      'No login or personal data is needed. Your diary and settings stay on your phone.';

  @override
  String trustScore(String score) {
    return 'Trust score $score';
  }

  @override
  String get openLink => 'Open';

  @override
  String get call => 'Call';

  @override
  String get map => 'Map';

  @override
  String get timings => 'Timings';

  @override
  String get address => 'Address';

  @override
  String get partnerMode => 'Partner mode';

  @override
  String get adminMode => 'Admin';

  @override
  String get signInGoogle => 'Sign in with Google';

  @override
  String get signOut => 'Sign out';

  @override
  String get partnerIntro =>
      'For co-operative societies and traders who share their daily rates. Farmers do not need to sign in.';

  @override
  String get partnerSubmitText =>
      'Type today\'s rates (market, variety, min, max, modal)';

  @override
  String get partnerAddPhoto => 'Add photo of rate board';

  @override
  String get submit => 'Submit';

  @override
  String get submitted =>
      'Submitted. It will be checked in the next collection run.';

  @override
  String get mySubmissions => 'My submissions';

  @override
  String get statusNew => 'Waiting';

  @override
  String get statusProcessed => 'Processed';

  @override
  String get statusFailed => 'Failed';

  @override
  String get partnerApply => 'Apply to become a partner';

  @override
  String get partnerPending =>
      'Your application is waiting for approval. After approval, sign out and sign in again.';

  @override
  String get partnerProfile => 'Your public profile';

  @override
  String get name => 'Name of society / shop';

  @override
  String get phone => 'Business phone';

  @override
  String get reportTitle => 'What is wrong?';

  @override
  String get reportPrice => 'Price is wrong';

  @override
  String get reportDate => 'Old / wrong date';

  @override
  String get reportOther => 'Other';

  @override
  String get reportSent => 'Thank you! We will check it.';

  @override
  String get changeLabel => 'Change';

  @override
  String asOf(String date) {
    return 'as of $date';
  }

  @override
  String get moreAlerts => 'Price alerts';

  @override
  String get adminReview => 'Review';

  @override
  String get adminPartners => 'Partners';

  @override
  String get adminConfig => 'Config';

  @override
  String get adminRuns => 'Runs';

  @override
  String get adminReports => 'Reports';

  @override
  String get approve => 'Approve';

  @override
  String get editApprove => 'Edit + approve';

  @override
  String get reject => 'Reject';

  @override
  String get flags => 'Flags';

  @override
  String get rawExcerpt => 'Raw source text';

  @override
  String get reviewEmpty => 'Nothing to review.';

  @override
  String get runNow => 'Run collection now (GitHub)';

  @override
  String get notAdmin =>
      'This account is not an admin yet. Run the GitHub workflow “Adike – set user role” (role: admin) for this email, then sign out and sign in again.';

  @override
  String get approved => 'Approved';

  @override
  String get sourceId => 'Source id';

  @override
  String get type => 'Type';

  @override
  String get aliasesJson => 'Alias maps (JSON)';

  @override
  String get savedOk => 'Saved';

  @override
  String get invalidJson => 'Invalid JSON';

  @override
  String get shareText =>
      'Today\'s arecanut & rubber rates — Adike Rubber Rates app';
}
