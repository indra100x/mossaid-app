import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ar'),
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Mossaid'**
  String get appTitle;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Find trusted craftsmen near you'**
  String get onboardingTitle;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneLabel;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'+213555123456'**
  String get phoneHint;

  /// No description provided for @sendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get sendOtp;

  /// No description provided for @otpLabel.
  ///
  /// In en, this message translates to:
  /// **'OTP code'**
  String get otpLabel;

  /// No description provided for @otpHint.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get otpHint;

  /// No description provided for @verifyOtp.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyOtp;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile setup'**
  String get profileTitle;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @roleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get roleLabel;

  /// No description provided for @roleClient.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get roleClient;

  /// No description provided for @roleCraftsman.
  ///
  /// In en, this message translates to:
  /// **'Craftsman'**
  String get roleCraftsman;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @saveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveProfile;

  /// No description provided for @craftsmanTradesLabel.
  ///
  /// In en, this message translates to:
  /// **'Trades'**
  String get craftsmanTradesLabel;

  /// No description provided for @craftsmanBioLabel.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get craftsmanBioLabel;

  /// No description provided for @craftsmanRadiusLabel.
  ///
  /// In en, this message translates to:
  /// **'Service radius (km)'**
  String get craftsmanRadiusLabel;

  /// No description provided for @craftsmanRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Hourly rate (DZD)'**
  String get craftsmanRateLabel;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search craftsmen'**
  String get searchTitle;

  /// No description provided for @searchTradeHint.
  ///
  /// In en, this message translates to:
  /// **'Trade (e.g. plumber)'**
  String get searchTradeHint;

  /// No description provided for @searchButton.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchButton;

  /// No description provided for @craftsmanProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Craftsman profile'**
  String get craftsmanProfileTitle;

  /// No description provided for @bookingRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Request booking'**
  String get bookingRequestTitle;

  /// No description provided for @bookingTradeLabel.
  ///
  /// In en, this message translates to:
  /// **'Trade'**
  String get bookingTradeLabel;

  /// No description provided for @bookingDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get bookingDescriptionLabel;

  /// No description provided for @bookingAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get bookingAddressLabel;

  /// No description provided for @bookingDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Scheduled date'**
  String get bookingDateLabel;

  /// No description provided for @bookingSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get bookingSubmit;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No craftsmen found'**
  String get searchNoResults;

  /// No description provided for @bookingSuccess.
  ///
  /// In en, this message translates to:
  /// **'Booking requested'**
  String get bookingSuccess;

  /// No description provided for @authFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed'**
  String get authFailed;

  /// No description provided for @validationFailed.
  ///
  /// In en, this message translates to:
  /// **'Validation failed'**
  String get validationFailed;

  /// No description provided for @verificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get verificationTitle;

  /// No description provided for @verificationDocType.
  ///
  /// In en, this message translates to:
  /// **'Document type'**
  String get verificationDocType;

  /// No description provided for @verificationFileName.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get verificationFileName;

  /// No description provided for @verificationUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get verificationUpload;

  /// No description provided for @verificationStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get verificationStatus;

  /// No description provided for @verifiedBadge.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verifiedBadge;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave a review'**
  String get reviewTitle;

  /// No description provided for @reviewRating.
  ///
  /// In en, this message translates to:
  /// **'Rating (1-5)'**
  String get reviewRating;

  /// No description provided for @reviewComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get reviewComment;

  /// No description provided for @reviewSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit review'**
  String get reviewSubmit;

  /// No description provided for @reviewSuccess.
  ///
  /// In en, this message translates to:
  /// **'Review submitted'**
  String get reviewSuccess;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTitle;

  /// No description provided for @chatPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Type a message'**
  String get chatPlaceholder;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatTyping.
  ///
  /// In en, this message translates to:
  /// **'Typing...'**
  String get chatTyping;

  /// No description provided for @chatRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get chatRead;
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
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
