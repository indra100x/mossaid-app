// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mossaid';

  @override
  String get onboardingTitle => 'Find trusted craftsmen near you';

  @override
  String get phoneLabel => 'Phone number';

  @override
  String get phoneHint => '+213555123456';

  @override
  String get sendOtp => 'Send OTP';

  @override
  String get otpLabel => 'OTP code';

  @override
  String get otpHint => '6-digit code';

  @override
  String get verifyOtp => 'Verify';

  @override
  String get profileTitle => 'Profile setup';

  @override
  String get nameLabel => 'Name';

  @override
  String get roleLabel => 'Role';

  @override
  String get roleClient => 'Client';

  @override
  String get roleCraftsman => 'Craftsman';

  @override
  String get languageLabel => 'Language';

  @override
  String get saveProfile => 'Save';

  @override
  String get craftsmanTradesLabel => 'Trades';

  @override
  String get craftsmanBioLabel => 'Bio';

  @override
  String get craftsmanRadiusLabel => 'Service radius (km)';

  @override
  String get craftsmanRateLabel => 'Hourly rate (DZD)';

  @override
  String get searchTitle => 'Search craftsmen';

  @override
  String get searchTradeHint => 'Trade (e.g. plumber)';

  @override
  String get searchButton => 'Search';

  @override
  String get craftsmanProfileTitle => 'Craftsman profile';

  @override
  String get bookingRequestTitle => 'Request booking';

  @override
  String get bookingTradeLabel => 'Trade';

  @override
  String get bookingDescriptionLabel => 'Description';

  @override
  String get bookingAddressLabel => 'Address';

  @override
  String get bookingDateLabel => 'Scheduled date';

  @override
  String get bookingSubmit => 'Send request';

  @override
  String get searchNoResults => 'No craftsmen found';

  @override
  String get bookingSuccess => 'Booking requested';

  @override
  String get authFailed => 'Authentication failed';

  @override
  String get validationFailed => 'Validation failed';
}
