// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Mossaid';

  @override
  String get onboardingTitle =>
      'Trouvez des artisans de confiance près de vous';

  @override
  String get phoneLabel => 'Numéro de téléphone';

  @override
  String get phoneHint => '+213555123456';

  @override
  String get sendOtp => 'Envoyer OTP';

  @override
  String get otpLabel => 'Code OTP';

  @override
  String get otpHint => 'Code à 6 chiffres';

  @override
  String get verifyOtp => 'Vérifier';

  @override
  String get profileTitle => 'Configuration du profil';

  @override
  String get nameLabel => 'Nom';

  @override
  String get roleLabel => 'Rôle';

  @override
  String get roleClient => 'Client';

  @override
  String get roleCraftsman => 'Artisan';

  @override
  String get languageLabel => 'Langue';

  @override
  String get saveProfile => 'Enregistrer';

  @override
  String get craftsmanTradesLabel => 'Métiers';

  @override
  String get craftsmanBioLabel => 'Bio';

  @override
  String get craftsmanRadiusLabel => 'Rayon de service (km)';

  @override
  String get craftsmanRateLabel => 'Tarif horaire (DZD)';

  @override
  String get searchTitle => 'Rechercher des artisans';

  @override
  String get searchTradeHint => 'Métier (ex. plombier)';

  @override
  String get searchButton => 'Rechercher';

  @override
  String get craftsmanProfileTitle => 'Profil artisan';

  @override
  String get bookingRequestTitle => 'Demande de réservation';

  @override
  String get bookingTradeLabel => 'Métier';

  @override
  String get bookingDescriptionLabel => 'Description';

  @override
  String get bookingAddressLabel => 'Adresse';

  @override
  String get bookingDateLabel => 'Date prévue';

  @override
  String get bookingSubmit => 'Envoyer la demande';

  @override
  String get searchNoResults => 'Aucun artisan trouvé';

  @override
  String get bookingSuccess => 'Réservation demandée';

  @override
  String get authFailed => 'Échec d\'authentification';

  @override
  String get validationFailed => 'Échec de validation';
}
