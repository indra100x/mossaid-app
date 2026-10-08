import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App locale (English / Arabic) with persistence. `null` = follow system.
class AppLocale extends ChangeNotifier {
  AppLocale();

  Locale? _locale;
  Locale? get locale => _locale;
  String get code => _locale?.languageCode ?? 'system';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _locale = switch (prefs.getString('locale')) {
        'en' => const Locale('en'),
        'ar' => const Locale('ar'),
        _ => null,
      };
    } catch (_) {}
    notifyListeners();
  }

  Future<void> set(String code) async {
    _locale = switch (code) {
      'en' => const Locale('en'),
      'ar' => const Locale('ar'),
      _ => null,
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('locale', code);
    } catch (_) {}
    notifyListeners();
  }
}

/// All user-visible strings. `tr` picks Arabic when the app locale is Arabic.
class Strings {
  static bool isAr(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar';

  /// Every key that must exist in both languages (used by tests).
  static Iterable<String> get keys => _en.keys;
  static bool hasAr(String key) => _ar.containsKey(key);

  static String t(
    BuildContext context,
    String key, [
    Map<String, String> params = const {},
  ]) {
    final map = isAr(context) ? _ar : _en;
    var s = map[key] ?? _en[key] ?? key;
    params.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }

  static const _en = {
    // Landing
    'tagline': 'Trusted craftsmen, one tap away',
    'landing_sub':
        'Clients post jobs · Craftsmen showcase work · Chat opens after accept.',
    'login': 'Login',
    'create_account': 'Create account',
    'perk_discover': 'Discover',
    'perk_chat': 'Chat on deal',
    'perk_rated': 'Rated pros',
    'checking_server': 'Checking server…',
    'server_ok': 'Server reachable ✓',
    'server_down': 'Server NOT reachable — check Wi-Fi / server',
    // Auth
    'welcome_back': 'Welcome back',
    'join_title': 'Join Mossaid',
    'login_blurb': 'Login to find craftsmen or manage your jobs.',
    'register_blurb':
        'Create your account — clients post jobs, craftsmen get discovered.',
    'segment_login': 'Login',
    'segment_register': 'Register',
    'full_name': 'Full name',
    'role_client': 'Client',
    'role_craftsman': 'Craftsman',
    'trade_label': 'Trade (painter, plumber…)',
    'city_optional': 'City (optional)',
    'email': 'Email',
    'password': 'Password',
    'password_min': 'Password (min 8 chars)',
    'btn_create': 'Create account',
    'btn_login': 'Login',
    'no_account': 'No account? Create one',
    'have_account': 'Already registered? Login',
    'forgot': 'Forgot password?',
    'v_name': 'Name is required',
    'v_email': 'Email is required',
    'v_email_bad': 'Enter a valid email',
    'v_password': 'Password is required',
    'v_password_min': 'At least 8 characters',
    // Home
    'salam': 'Salam, {name} 👋',
    'tab_discover': 'Discover',
    'tab_jobs': 'Jobs',
    'tab_alerts': 'Alerts',
    'tab_account': 'Account',
    'tab_mywork': 'My work',
    'tab_requests': 'Requests',
    // Posts
    'search_crafts': 'Search painter, plumber…',
    'publish_work': 'Publish your work',
    'no_posts': 'No posts yet — craftsmen, publish the first one! 👆',
    'retry': 'Retry',
    'chip_all': 'All',
    'new_craftsman': 'New craftsman',
    'comments_title': 'Comments ({n})',
    'comment_hint': 'Add a comment…',
    // Jobs
    'search_jobs': 'Search jobs…',
    'status_all': 'all',
    'status_open': 'open',
    'status_accepted': 'accepted',
    'status_completed': 'completed',
    'status_cancelled': 'cancelled',
    'post_job_btn': 'Post a job request',
    'no_jobs': 'No jobs yet — clients, post the first request! 👆',
    // Post form
    'showcase_title': 'Showcase your work',
    'f_title': 'Title',
    'f_title_hint_post': 'Give your post a title',
    'f_trade': 'Trade',
    'f_trade_hint': 'Trade (painter, plumber, electrician…)',
    'f_trade_required': 'Trade is required',
    'f_pick_trade': 'Pick your trade',
    'f_city': 'City',
    'f_price': 'Price (DZD)',
    'f_desc_work': 'Describe your work, experience, materials…',
    'f_desc_min': 'A few more details help clients trust you',
    'f_add_photo': 'Add photo',
    'f_publish': 'Publish post',
    // Job form
    'job_title': 'Describe your job',
    'f_need': 'What do you need? (e.g. Repaint living room)',
    'f_need_trade': 'Trade needed',
    'f_budget': 'Budget DZD (optional)',
    'f_job_details': 'Details: size, materials, timing…',
    'f_job_details_min': 'Add a few details so craftsmen can respond',
    'f_cover': 'Add a photo of the job (optional)',
    'f_post_job': 'Post job request',
    'f_title_required': 'Title is required',
    'f_required': 'Required',
    // Job detail
    'accept_open_chat': 'Accept job → open chat',
    'mark_completed': 'Mark completed',
    'cancel': 'Cancel',
    'rate_craftsman': 'Rate craftsman',
    'thanks_review': 'Thanks for the review! ⭐',
    'chat_live': 'Chat (updates every 5s)',
    'say_salam': 'Say salam! 👋',
    'message_hint': 'Message…',
    'send_failed': 'Send failed: {e}',
    'load_job_failed': 'Could not load job: {e}',
    'tl_posted': 'Posted',
    'tl_accepted': 'Accepted',
    'tl_done': 'Done',
    'tl_cancelled': 'This job was cancelled',
    // Review dialog
    'rate_title': 'Rate this craftsman',
    'rate_hint': 'What went well? (optional)',
    'later': 'Later',
    'send_review': 'Send review',
    // Craftsman profile
    'reviews_title': 'Reviews ({n})',
    'no_reviews': 'No reviews yet — be the first after a job!',
    'my_trade': 'My trade',
    // Notifications
    'alerts_title': 'Alerts',
    'mark_all_read': 'Mark all read',
    'nt_accepted_t': '{actor} accepted your job',
    'nt_accepted_b': 'Chat is now open — talk it through 🤝',
    'nt_message_t': 'New message from {actor}',
    'nt_completed_t': 'Job completed',
    'nt_completed_b': '{actor} closed the job',
    'nt_review_t': 'New {rating}★ review',
    'nt_review_b': '{actor} reviewed your work',
    'no_alerts': 'Nothing yet — accepts and messages land here.',
    // Account
    'edit_profile': 'Edit profile',
    'edit_profile_sub': 'Name, phone, trade, city, bio',
    'my_jobs': 'My jobs',
    'my_jobs_sub_client': 'Track your requests and chats here',
    'my_jobs_sub_craft': 'Accepted work and requests appear here',
    'marketplace': 'Marketplace',
    'marketplace_sub_client': 'Browse craftsmen under Posts',
    'marketplace_sub_craft': 'Your portfolio posts live under Posts',
    'appearance': 'Appearance',
    'appearance_dark': 'Dark mode — tap for light',
    'appearance_light': 'Light mode — tap for dark',
    'language': 'Language / اللغة',
    'language_sub': 'English · العربية',
    'logout': 'Logout',
    // Profile edit
    'edit_title': 'Edit profile',
    'f_phone': 'Phone (optional)',
    'f_bio': 'Bio (optional)',
    'save': 'Save',
    // Forgot password
    'reset_title': 'Reset password',
    'reset_step1': 'Enter your account email to get a reset code.',
    'send_code': 'Send code',
    'code_is': 'Code: {code} (enter it below)',
    'code_sent': 'If this email exists, a code was sent.',
    'code_label': '6-digit code',
    'new_password': 'New password (8+ chars)',
    'change_password': 'Change password',
    'code_hint': 'The code has 6 digits',
    'pass_hint': 'Password needs 8+ characters',
    'password_changed': 'Password changed — login now.',
    // Errors / misc
    'post_word': 'Post',
    'job_word': 'Job',
    'timeout': 'Server not reachable (timeout). Is the API running?',
    'no_connection': 'No connection to the server ({e}).',
    'conn_failed': 'Connection failed: {e}',
    'load_failed': 'Could not load: {e}',
    'load_post_failed': 'Could not load post: {e}',
    'op_failed': 'Failed: {e}',
    'reach_failed': 'Could not reach the server: {e}',
    'upload_timeout': 'Upload timed out. Try a smaller photo.',
    'upload_failed': 'Upload failed: {e}',
    'photo_failed': 'Photo failed: {e}',
  };

  static const _ar = {
    // Landing
    'tagline': 'حرفيون موثوقون بضغطة واحدة',
    'landing_sub':
        'الزبائن ينشرون الأعمال · الحرفيون يعرضون أعمالهم · المحادثة تُفتح بعد الاتفاق.',
    'login': 'تسجيل الدخول',
    'create_account': 'إنشاء حساب',
    'perk_discover': 'اكتشف',
    'perk_chat': 'محادثة عند الاتفاق',
    'perk_rated': 'حرفيون مُقيَّمون',
    'checking_server': 'جارٍ التحقق من الخادم…',
    'server_ok': 'الخادم متصل ✓',
    'server_down': 'الخادم غير متصل — تحقق من الواي فاي / الخادم',
    // Auth
    'welcome_back': 'مرحباً بعودتك',
    'join_title': 'انضم إلى مساعد',
    'login_blurb': 'سجّل الدخول للعثور على حرفيين أو متابعة أعمالك.',
    'register_blurb': 'أنشئ حسابك — الزبائن ينشرون الأعمال والحرفيون يُكتشفون.',
    'segment_login': 'دخول',
    'segment_register': 'تسجيل',
    'full_name': 'الاسم الكامل',
    'role_client': 'زبون',
    'role_craftsman': 'حرفي',
    'trade_label': 'الحرفة (دهّان، سبّاك…)',
    'city_optional': 'المدينة (اختياري)',
    'email': 'البريد الإلكتروني',
    'password': 'كلمة المرور',
    'password_min': 'كلمة المرور (8 أحرف فأكثر)',
    'btn_create': 'إنشاء الحساب',
    'btn_login': 'تسجيل الدخول',
    'no_account': 'ليس لديك حساب؟ أنشئ واحداً',
    'have_account': 'مسجل من قبل؟ سجّل الدخول',
    'forgot': 'نسيت كلمة المرور؟',
    'v_name': 'الاسم مطلوب',
    'v_email': 'البريد الإلكتروني مطلوب',
    'v_email_bad': 'أدخل بريداً صحيحاً',
    'v_password': 'كلمة المرور مطلوبة',
    'v_password_min': '8 أحرف على الأقل',
    // Home
    'salam': 'سلام، {name} 👋',
    'tab_discover': 'اكتشف',
    'tab_jobs': 'الأعمال',
    'tab_alerts': 'التنبيهات',
    'tab_account': 'الحساب',
    'tab_mywork': 'أعمالي',
    'tab_requests': 'الطلبات',
    // Posts
    'search_crafts': 'ابحث دهّان، سبّاك…',
    'publish_work': 'انشر أعمالك',
    'no_posts': 'لا منشورات بعد — أيها الحرفيون، انشروا أول عمل! 👆',
    'retry': 'إعادة المحاولة',
    'chip_all': 'الكل',
    'new_craftsman': 'حرفي جديد',
    'comments_title': 'التعليقات ({n})',
    'comment_hint': 'أضف تعليقاً…',
    // Jobs
    'search_jobs': 'ابحث في الأعمال…',
    'status_all': 'قاع',
    'status_open': 'جدد',
    'status_accepted': 'مقبولين',
    'status_completed': 'كاملين',
    'status_cancelled': 'ملغيين',
    'post_job_btn': 'انشر طلب عمل',
    'no_jobs': 'لا أعمال بعد — أيها الزبائن، انشروا أول طلب! 👆',
    // Post form
    'showcase_title': 'اعرض أعمالك',
    'f_title': 'العنوان',
    'f_title_hint_post': 'أعطِ منشورك عنواناً',
    'f_trade': 'الحرفة',
    'f_trade_hint': 'الحرفة (دهّان، سبّاك، كهربائي…)',
    'f_trade_required': 'الحرفة مطلوبة',
    'f_pick_trade': 'اختر حرفتك',
    'f_city': 'المدينة',
    'f_price': 'السعر (دج)',
    'f_desc_work': 'صف عملك وخبرتك والمواد…',
    'f_desc_min': 'بعض التفاصيل تساعد الزبائن على الثقة بك',
    'f_add_photo': 'أضف صورة',
    'f_publish': 'انشر المنشور',
    // Job form
    'job_title': 'صف عملك',
    'f_need': 'ماذا تحتاج؟ (مثال: إعادة دهن غرفة الجلوس)',
    'f_need_trade': 'الحرفة المطلوبة',
    'f_budget': 'الميزانية دج (اختياري)',
    'f_job_details': 'التفاصيل: المساحة، المواد، التوقيت…',
    'f_job_details_min': 'أضف تفاصيل ليتمكن الحرفيون من الرد',
    'f_cover': 'أضف صورة للعمل (اختياري)',
    'f_post_job': 'انشر طلب العمل',
    'f_title_required': 'العنوان مطلوب',
    'f_required': 'مطلوب',
    // Job detail
    'accept_open_chat': 'اقبل العمل ← افتح المحادثة',
    'mark_completed': 'أنجز العمل',
    'cancel': 'إلغاء',
    'rate_craftsman': 'قيّم الحرفي',
    'thanks_review': 'شكراً على التقييم! ⭐',
    'chat_live': 'المحادثة (تتحدث كل 5 ثوانٍ)',
    'say_salam': 'قل سلام! 👋',
    'message_hint': 'رسالة…',
    'send_failed': 'فشل الإرسال: {e}',
    'load_job_failed': 'تعذر تحميل العمل: {e}',
    'tl_posted': 'منشور',
    'tl_accepted': 'مقبول',
    'tl_done': 'مكتمل',
    'tl_cancelled': 'تم إلغاء هذا العمل',
    // Review dialog
    'rate_title': 'قيّم هذا الحرفي',
    'rate_hint': 'ما الذي أعجبك؟ (اختياري)',
    'later': 'لاحقاً',
    'send_review': 'أرسل التقييم',
    // Craftsman profile
    'reviews_title': 'التقييمات ({n})',
    'no_reviews': 'لا تقييمات بعد — كن الأول بعد العمل!',
    'my_trade': 'حرفتي',
    // Notifications
    'alerts_title': 'التنبيهات',
    'mark_all_read': 'تعليم الكل كمقروء',
    'nt_accepted_t': '{actor} قبل طلب العمل',
    'nt_accepted_b': 'المحادثة انفتحت — تفاهم معاه 🤝',
    'nt_message_t': 'رسالة جديدة من {actor}',
    'nt_completed_t': 'تكمل العمل',
    'nt_completed_b': '{actor} أعلن نهاية الخدمة',
    'nt_review_t': 'تقييم جديد {rating}⭐',
    'nt_review_b': '{actor} قيّم الخدمة تاعك',
    'no_alerts': 'لا شيء بعد — القبول والرسائل تصل هنا.',
    // Account
    'edit_profile': 'تعديل الحساب',
    'edit_profile_sub': 'الاسم، الهاتف، الحرفة، المدينة، النبذة',
    'my_jobs': 'أعمالي',
    'my_jobs_sub_client': 'تابع طلباتك ومحادثاتك هنا',
    'my_jobs_sub_craft': 'الأعمال المقبولة والطلبات تظهر هنا',
    'marketplace': 'السوق',
    'marketplace_sub_client': 'تصفح الحرفيين في المنشورات',
    'marketplace_sub_craft': 'منشورات أعمالك في قسم المنشورات',
    'appearance': 'المظهر',
    'appearance_dark': 'الوضع الداكن — اضغط للفاتح',
    'appearance_light': 'الوضع الفاتح — اضغط للداكن',
    'language': 'اللغة / Language',
    'language_sub': 'العربية · English',
    'logout': 'تسجيل الخروج',
    // Profile edit
    'edit_title': 'تعديل الحساب',
    'f_phone': 'الهاتف (اختياري)',
    'f_bio': 'نبذة (اختياري)',
    'save': 'حفظ',
    // Forgot password
    'reset_title': 'استعادة كلمة المرور',
    'reset_step1': 'أدخل بريد حسابك للحصول على رمز الاستعادة.',
    'send_code': 'أرسل الرمز',
    'code_is': 'الرمز: {code} (أدخله أدناه)',
    'code_sent': 'إذا كان هذا البريد موجوداً، تم إرسال رمز.',
    'code_label': 'رمز من 6 أرقام',
    'new_password': 'كلمة مرور جديدة (8+ أحرف)',
    'change_password': 'غيّر كلمة المرور',
    'code_hint': 'الرمز من 6 أرقام',
    'pass_hint': 'كلمة المرور 8 أحرف فأكثر',
    'password_changed': 'تم تغيير كلمة المرور — سجّل الدخول الآن.',
    // Errors / misc
    'post_word': 'منشور',
    'job_word': 'عمل',
    'timeout': 'تعذر الوصول للخادم (انتهت المهلة). هل يعمل؟',
    'no_connection': 'لا اتصال بالخادم ({e}).',
    'conn_failed': 'فشل الاتصال: {e}',
    'load_failed': 'تعذر التحميل: {e}',
    'load_post_failed': 'تعذر تحميل المنشور: {e}',
    'op_failed': 'فشل: {e}',
    'reach_failed': 'تعذر الوصول للخادم: {e}',
    'upload_timeout': 'انتهت مهلة الرفع. جرّب صورة أصغر.',
    'upload_failed': 'فشل الرفع: {e}',
    'photo_failed': 'فشلت الصورة: {e}',
  };
}
