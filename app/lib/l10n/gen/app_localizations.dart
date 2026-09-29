import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_kn.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('kn'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Adike–Rubber Dhara'**
  String get appTitle;

  /// No description provided for @navToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// No description provided for @navCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get navCompare;

  /// No description provided for @navCalculator.
  ///
  /// In en, this message translates to:
  /// **'Calculator'**
  String get navCalculator;

  /// No description provided for @navDiary.
  ///
  /// In en, this message translates to:
  /// **'Diary'**
  String get navDiary;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @cropArecanut.
  ///
  /// In en, this message translates to:
  /// **'Arecanut'**
  String get cropArecanut;

  /// No description provided for @cropRubber.
  ///
  /// In en, this message translates to:
  /// **'Rubber'**
  String get cropRubber;

  /// No description provided for @unitQuintal.
  ///
  /// In en, this message translates to:
  /// **'₹/quintal'**
  String get unitQuintal;

  /// No description provided for @unitKg.
  ///
  /// In en, this message translates to:
  /// **'₹/kg'**
  String get unitKg;

  /// No description provided for @badgeOfficial.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get badgeOfficial;

  /// No description provided for @badgePartner.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get badgePartner;

  /// No description provided for @badgeTrader.
  ///
  /// In en, this message translates to:
  /// **'Trader'**
  String get badgeTrader;

  /// No description provided for @modal.
  ///
  /// In en, this message translates to:
  /// **'Modal'**
  String get modal;

  /// No description provided for @minLabel.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get minLabel;

  /// No description provided for @maxLabel.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get maxLabel;

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated: {time}'**
  String lastUpdated(String time);

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'Offline — showing saved rates from {time}'**
  String offlineBanner(String time);

  /// No description provided for @loadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load rates. Check internet and pull to refresh.'**
  String get loadError;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No rates available'**
  String get noData;

  /// No description provided for @myMarkets.
  ///
  /// In en, this message translates to:
  /// **'My markets'**
  String get myMarkets;

  /// No description provided for @otherMarkets.
  ///
  /// In en, this message translates to:
  /// **'Other markets'**
  String get otherMarkets;

  /// No description provided for @summaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s summary'**
  String get summaryTitle;

  /// No description provided for @summaryNote.
  ///
  /// In en, this message translates to:
  /// **'Auto-written only from published rates. Not advice.'**
  String get summaryNote;

  /// No description provided for @sampleData.
  ///
  /// In en, this message translates to:
  /// **'SAMPLE data — not real prices'**
  String get sampleData;

  /// No description provided for @pickMarketsTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your markets'**
  String get pickMarketsTitle;

  /// No description provided for @pickMarketsHint.
  ///
  /// In en, this message translates to:
  /// **'Your markets are shown first. You can change them later in Settings.'**
  String get pickMarketsHint;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @regionCoastal.
  ///
  /// In en, this message translates to:
  /// **'Coastal'**
  String get regionCoastal;

  /// No description provided for @regionMalnad.
  ///
  /// In en, this message translates to:
  /// **'Malnad'**
  String get regionMalnad;

  /// No description provided for @regionOther.
  ///
  /// In en, this message translates to:
  /// **'Other Karnataka'**
  String get regionOther;

  /// No description provided for @regionKerala.
  ///
  /// In en, this message translates to:
  /// **'Kerala'**
  String get regionKerala;

  /// No description provided for @range7d.
  ///
  /// In en, this message translates to:
  /// **'7D'**
  String get range7d;

  /// No description provided for @range1m.
  ///
  /// In en, this message translates to:
  /// **'1M'**
  String get range1m;

  /// No description provided for @range6m.
  ///
  /// In en, this message translates to:
  /// **'6M'**
  String get range6m;

  /// No description provided for @range1y.
  ///
  /// In en, this message translates to:
  /// **'1Y'**
  String get range1y;

  /// No description provided for @seasonCompare.
  ///
  /// In en, this message translates to:
  /// **'Same period last year'**
  String get seasonCompare;

  /// No description provided for @thisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get thisYear;

  /// No description provided for @recentDays.
  ///
  /// In en, this message translates to:
  /// **'Recent days'**
  String get recentDays;

  /// No description provided for @allSources.
  ///
  /// In en, this message translates to:
  /// **'All sources'**
  String get allSources;

  /// No description provided for @setAlert.
  ///
  /// In en, this message translates to:
  /// **'Set alert'**
  String get setAlert;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @reportWrong.
  ///
  /// In en, this message translates to:
  /// **'Report wrong rate'**
  String get reportWrong;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get noHistory;

  /// No description provided for @compareTitle.
  ///
  /// In en, this message translates to:
  /// **'Compare markets'**
  String get compareTitle;

  /// No description provided for @variety.
  ///
  /// In en, this message translates to:
  /// **'Variety'**
  String get variety;

  /// No description provided for @market.
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get market;

  /// No description provided for @alertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Price alerts'**
  String get alertsTitle;

  /// No description provided for @alertAbove.
  ///
  /// In en, this message translates to:
  /// **'Goes above'**
  String get alertAbove;

  /// No description provided for @alertBelow.
  ///
  /// In en, this message translates to:
  /// **'Falls below'**
  String get alertBelow;

  /// No description provided for @alertValue.
  ///
  /// In en, this message translates to:
  /// **'Price (₹)'**
  String get alertValue;

  /// No description provided for @alertCreate.
  ///
  /// In en, this message translates to:
  /// **'Create alert'**
  String get alertCreate;

  /// No description provided for @alertNone.
  ///
  /// In en, this message translates to:
  /// **'No alerts yet. Open a rate and tap “Set alert”.'**
  String get alertNone;

  /// No description provided for @alertSaved.
  ///
  /// In en, this message translates to:
  /// **'Alert saved. You will get a notification once a day at most.'**
  String get alertSaved;

  /// No description provided for @alertLine.
  ///
  /// In en, this message translates to:
  /// **'{variety} · {market}: {condition} {value}'**
  String alertLine(
    String variety,
    String market,
    String condition,
    String value,
  );

  /// No description provided for @needsOnline.
  ///
  /// In en, this message translates to:
  /// **'This needs internet and the app\'s online services.'**
  String get needsOnline;

  /// No description provided for @notConfigured.
  ///
  /// In en, this message translates to:
  /// **'Online services are not configured in this build.'**
  String get notConfigured;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {error}'**
  String errorGeneric(String error);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @calcTitle.
  ///
  /// In en, this message translates to:
  /// **'Sale calculator'**
  String get calcTitle;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @unitKgShort.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get unitKgShort;

  /// No description provided for @unitQuintalShort.
  ///
  /// In en, this message translates to:
  /// **'quintal'**
  String get unitQuintalShort;

  /// No description provided for @unitBags.
  ///
  /// In en, this message translates to:
  /// **'bags'**
  String get unitBags;

  /// No description provided for @bagWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight per bag (kg)'**
  String get bagWeight;

  /// No description provided for @rate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rate;

  /// No description provided for @useTodayRate.
  ///
  /// In en, this message translates to:
  /// **'Use today\'s rate'**
  String get useTodayRate;

  /// No description provided for @commissionPct.
  ///
  /// In en, this message translates to:
  /// **'Commission %'**
  String get commissionPct;

  /// No description provided for @hamali.
  ///
  /// In en, this message translates to:
  /// **'Hamali (₹)'**
  String get hamali;

  /// No description provided for @transport.
  ///
  /// In en, this message translates to:
  /// **'Transport (₹)'**
  String get transport;

  /// No description provided for @gross.
  ///
  /// In en, this message translates to:
  /// **'Gross amount'**
  String get gross;

  /// No description provided for @deductions.
  ///
  /// In en, this message translates to:
  /// **'Deductions'**
  String get deductions;

  /// No description provided for @net.
  ///
  /// In en, this message translates to:
  /// **'Net amount'**
  String get net;

  /// No description provided for @totalKg.
  ///
  /// In en, this message translates to:
  /// **'Total weight: {kg} kg'**
  String totalKg(String kg);

  /// No description provided for @diaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales diary'**
  String get diaryTitle;

  /// No description provided for @diaryAdd.
  ///
  /// In en, this message translates to:
  /// **'Add sale'**
  String get diaryAdd;

  /// No description provided for @diaryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sales recorded yet.'**
  String get diaryEmpty;

  /// No description provided for @diaryBuyer.
  ///
  /// In en, this message translates to:
  /// **'Buyer / society'**
  String get diaryBuyer;

  /// No description provided for @diaryNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get diaryNote;

  /// No description provided for @diaryAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount received (₹)'**
  String get diaryAmount;

  /// No description provided for @diaryQtyKg.
  ///
  /// In en, this message translates to:
  /// **'Quantity (kg)'**
  String get diaryQtyKg;

  /// No description provided for @seasonTotal.
  ///
  /// In en, this message translates to:
  /// **'Season {season} total'**
  String seasonTotal(String season);

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportCsv;

  /// No description provided for @diaryPrivate.
  ///
  /// In en, this message translates to:
  /// **'Your diary stays only on this phone.'**
  String get diaryPrivate;

  /// No description provided for @weatherTitle.
  ///
  /// In en, this message translates to:
  /// **'Drying weather'**
  String get weatherTitle;

  /// No description provided for @dryGood.
  ///
  /// In en, this message translates to:
  /// **'Good drying day'**
  String get dryGood;

  /// No description provided for @dryRisky.
  ///
  /// In en, this message translates to:
  /// **'Risky'**
  String get dryRisky;

  /// No description provided for @dryBad.
  ///
  /// In en, this message translates to:
  /// **'Bad drying day'**
  String get dryBad;

  /// No description provided for @dryRule.
  ///
  /// In en, this message translates to:
  /// **'Daytime 8 am–5 pm. Good: rain < 0.5 mm, humidity < 80%, cloud < 70%. Bad: rain ≥ 2 mm or humidity ≥ 90%. Otherwise risky.'**
  String get dryRule;

  /// No description provided for @weatherStats.
  ///
  /// In en, this message translates to:
  /// **'Rain {rain} mm · Humidity {hum}% · Cloud {cloud}%'**
  String weatherStats(String rain, String hum, String cloud);

  /// No description provided for @weatherAttribution.
  ///
  /// In en, this message translates to:
  /// **'Weather data: MET Norway (api.met.no), CC BY 4.0'**
  String get weatherAttribution;

  /// No description provided for @weatherPlace.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get weatherPlace;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @shareCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Share card'**
  String get shareCardTitle;

  /// No description provided for @shareCardHint.
  ///
  /// In en, this message translates to:
  /// **'Shows today\'s rates for your markets. Share it on WhatsApp.'**
  String get shareCardHint;

  /// No description provided for @shareNow.
  ///
  /// In en, this message translates to:
  /// **'Share image'**
  String get shareNow;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings & about'**
  String get settingsTitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @dailySummaryNotif.
  ///
  /// In en, this message translates to:
  /// **'Daily evening summary'**
  String get dailySummaryNotif;

  /// No description provided for @dataSources.
  ///
  /// In en, this message translates to:
  /// **'Data sources'**
  String get dataSources;

  /// No description provided for @disclaimer.
  ///
  /// In en, this message translates to:
  /// **'Rates are indicative only; confirm with the buyer before selling.'**
  String get disclaimer;

  /// No description provided for @privacyNote.
  ///
  /// In en, this message translates to:
  /// **'No login or personal data is needed. Your diary and settings stay on your phone.'**
  String get privacyNote;

  /// No description provided for @trustScore.
  ///
  /// In en, this message translates to:
  /// **'Trust score {score}'**
  String trustScore(String score);

  /// No description provided for @openLink.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openLink;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// No description provided for @timings.
  ///
  /// In en, this message translates to:
  /// **'Timings'**
  String get timings;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @partnerMode.
  ///
  /// In en, this message translates to:
  /// **'Partner mode'**
  String get partnerMode;

  /// No description provided for @adminMode.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminMode;

  /// No description provided for @signInGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInGoogle;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @partnerIntro.
  ///
  /// In en, this message translates to:
  /// **'For co-operative societies and traders who share their daily rates. Farmers do not need to sign in.'**
  String get partnerIntro;

  /// No description provided for @partnerSubmitText.
  ///
  /// In en, this message translates to:
  /// **'Type today\'s rates (market, variety, min, max, modal)'**
  String get partnerSubmitText;

  /// No description provided for @partnerAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo of rate board'**
  String get partnerAddPhoto;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @submitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted. It will be checked in the next collection run.'**
  String get submitted;

  /// No description provided for @mySubmissions.
  ///
  /// In en, this message translates to:
  /// **'My submissions'**
  String get mySubmissions;

  /// No description provided for @statusNew.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get statusNew;

  /// No description provided for @statusProcessed.
  ///
  /// In en, this message translates to:
  /// **'Processed'**
  String get statusProcessed;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @partnerApply.
  ///
  /// In en, this message translates to:
  /// **'Apply to become a partner'**
  String get partnerApply;

  /// No description provided for @partnerPending.
  ///
  /// In en, this message translates to:
  /// **'Your application is waiting for approval. After approval, sign out and sign in again.'**
  String get partnerPending;

  /// No description provided for @partnerProfile.
  ///
  /// In en, this message translates to:
  /// **'Your public profile'**
  String get partnerProfile;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name of society / shop'**
  String get name;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Business phone'**
  String get phone;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'What is wrong?'**
  String get reportTitle;

  /// No description provided for @reportPrice.
  ///
  /// In en, this message translates to:
  /// **'Price is wrong'**
  String get reportPrice;

  /// No description provided for @reportDate.
  ///
  /// In en, this message translates to:
  /// **'Old / wrong date'**
  String get reportDate;

  /// No description provided for @reportOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reportOther;

  /// No description provided for @reportSent.
  ///
  /// In en, this message translates to:
  /// **'Thank you! We will check it.'**
  String get reportSent;

  /// No description provided for @changeLabel.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeLabel;

  /// No description provided for @asOf.
  ///
  /// In en, this message translates to:
  /// **'as of {date}'**
  String asOf(String date);

  /// No description provided for @moreAlerts.
  ///
  /// In en, this message translates to:
  /// **'Price alerts'**
  String get moreAlerts;

  /// No description provided for @adminReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get adminReview;

  /// No description provided for @adminPartners.
  ///
  /// In en, this message translates to:
  /// **'Partners'**
  String get adminPartners;

  /// No description provided for @adminConfig.
  ///
  /// In en, this message translates to:
  /// **'Config'**
  String get adminConfig;

  /// No description provided for @adminRuns.
  ///
  /// In en, this message translates to:
  /// **'Runs'**
  String get adminRuns;

  /// No description provided for @adminReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get adminReports;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @editApprove.
  ///
  /// In en, this message translates to:
  /// **'Edit + approve'**
  String get editApprove;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @flags.
  ///
  /// In en, this message translates to:
  /// **'Flags'**
  String get flags;

  /// No description provided for @rawExcerpt.
  ///
  /// In en, this message translates to:
  /// **'Raw source text'**
  String get rawExcerpt;

  /// No description provided for @reviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to review.'**
  String get reviewEmpty;

  /// No description provided for @runNow.
  ///
  /// In en, this message translates to:
  /// **'Run collection now (GitHub)'**
  String get runNow;

  /// No description provided for @notAdmin.
  ///
  /// In en, this message translates to:
  /// **'This account is not an admin yet. Run the GitHub workflow “Adike – set user role” (role: admin) for this email, then sign out and sign in again.'**
  String get notAdmin;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @sourceId.
  ///
  /// In en, this message translates to:
  /// **'Source id'**
  String get sourceId;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @aliasesJson.
  ///
  /// In en, this message translates to:
  /// **'Alias maps (JSON)'**
  String get aliasesJson;

  /// No description provided for @savedOk.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedOk;

  /// No description provided for @invalidJson.
  ///
  /// In en, this message translates to:
  /// **'Invalid JSON'**
  String get invalidJson;

  /// No description provided for @shareText.
  ///
  /// In en, this message translates to:
  /// **'Today\'s arecanut & rubber rates — Adike–Rubber Dhara app'**
  String get shareText;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'kn'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'kn':
      return AppLocalizationsKn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
