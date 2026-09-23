// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'مساعد';

  @override
  String get onboardingTitle => 'اعثر على حرفيين موثوقين بالقرب منك';

  @override
  String get phoneLabel => 'رقم الهاتف';

  @override
  String get phoneHint => '+213555123456';

  @override
  String get sendOtp => 'إرسال الرمز';

  @override
  String get otpLabel => 'رمز التحقق';

  @override
  String get otpHint => 'رمز من 6 أرقام';

  @override
  String get verifyOtp => 'تحقق';

  @override
  String get profileTitle => 'إعداد الملف الشخصي';

  @override
  String get nameLabel => 'الاسم';

  @override
  String get roleLabel => 'الدور';

  @override
  String get roleClient => 'عميل';

  @override
  String get roleCraftsman => 'حرفي';

  @override
  String get languageLabel => 'اللغة';

  @override
  String get saveProfile => 'حفظ';

  @override
  String get craftsmanTradesLabel => 'المهن';

  @override
  String get craftsmanBioLabel => 'نبذة';

  @override
  String get craftsmanRadiusLabel => 'نطاق الخدمة (كم)';

  @override
  String get craftsmanRateLabel => 'السعر بالساعة (دج)';

  @override
  String get searchTitle => 'البحث عن الحرفيين';

  @override
  String get searchTradeHint => 'المهنة (مثال: سباك)';

  @override
  String get searchButton => 'بحث';

  @override
  String get craftsmanProfileTitle => 'ملف الحرفي';

  @override
  String get bookingRequestTitle => 'طلب حجز';

  @override
  String get bookingTradeLabel => 'المهنة';

  @override
  String get bookingDescriptionLabel => 'الوصف';

  @override
  String get bookingAddressLabel => 'العنوان';

  @override
  String get bookingDateLabel => 'التاريخ';

  @override
  String get bookingSubmit => 'إرسال الطلب';

  @override
  String get searchNoResults => 'لم يتم العثور على حرفيين';

  @override
  String get bookingSuccess => 'تم إرسال الطلب';

  @override
  String get authFailed => 'فشل تسجيل الدخول';

  @override
  String get validationFailed => 'فشل التحقق';
}
