import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'api.dart';
import 'app_theme.dart';
import 'design_tokens.dart';
import 'job_timeline.dart';
import 'meta.dart';
import 'session.dart';
import 'strings.dart';
import 'strings.dart';

void main() {
  final api = ApiClient();
  final session = Session(api)..load();
  final theme = AppTheme()..load();
  final appLocale = AppLocale()..load();
  runApp(
    MossaidSimple(session: session, api: api, theme: theme, locale: appLocale),
  );
}

class MossaidSimple extends StatelessWidget {
  const MossaidSimple({
    super.key,
    required this.session,
    required this.api,
    required this.theme,
    required this.locale,
  });
  final Session session;
  final ApiClient api;
  final AppTheme theme;
  final AppLocale locale;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([session, theme, locale]),
      builder: (_, __) => AppThemeScope(
        theme: theme,
        locale: locale,
        child: MaterialApp(
          title: 'Mossaid',
          theme: buildTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: theme.mode,
          locale: locale.locale,
          supportedLocales: const [Locale('en'), Locale('ar'), Locale('fr')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: !session.loaded
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : session.loggedIn
              ? HomeScreen(
                  session: session,
                  api: api,
                  theme: theme,
                  locale: locale,
                )
              : LandingScreen(session: session, api: api, locale: locale),
        ),
      ),
    );
  }
}

/// Makes the [AppTheme] + [AppLocale] reachable from any page.
class AppThemeScope extends InheritedWidget {
  const AppThemeScope({
    super.key,
    required this.theme,
    required this.locale,
    required super.child,
  });
  final AppTheme theme;
  final AppLocale locale;

  static AppThemeScope _scope(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    assert(scope != null, 'AppThemeScope not found above.');
    return scope!;
  }

  static AppTheme themeOf(BuildContext context) => _scope(context).theme;
  static AppLocale localeOf(BuildContext context) => _scope(context).locale;

  /// Back-compat: existing callers use `AppThemeScope.of(context)` for theme.
  static AppTheme of(BuildContext context) => themeOf(context);

  @override
  bool updateShouldNotify(AppThemeScope oldWidget) =>
      theme != oldWidget.theme || locale != oldWidget.locale;
}

/// Globe button opening English / Français / العربية — same spots as theme.
class LanguageMenuButton extends StatelessWidget {
  const LanguageMenuButton({super.key, this.color});
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final loc = AppThemeScope.localeOf(context);
    return PopupMenuButton<String>(
      tooltip: Strings.t(context, 'language'),
      icon: Icon(Icons.language_outlined, color: color),
      onSelected: (v) => loc.set(v),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'ar', child: Text('العربية')),
        PopupMenuItem(value: 'fr', child: Text('Français')),
        PopupMenuItem(value: 'en', child: Text('English')),
      ],
    );
  }
}

/// Moon/sun button — drop into any AppBar `actions` (or overlay).
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, this.color});
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: dark
          ? Strings.t(context, 'appearance_dark')
          : Strings.t(context, 'appearance_light'),
      color: color,
      icon: Icon(dark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined),
      onPressed: () => theme.toggle(context),
    );
  }
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kTeal,
    secondary: kAmber,
    surface: Colors.white,
  );
  final baseText = Typography.englishLike2021.apply(fontFamily: 'Jakarta');
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: kPaper,
    useMaterial3: true,
    fontFamily: 'Jakarta',
    fontFamilyFallback: const ['Rubik'],
    textTheme: baseText.copyWith(
      titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kPaper,
      foregroundColor: kInk,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleTextStyle: TextStyle(
        fontFamily: 'Jakarta',
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: kInk,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: kTeal, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: kInk.withValues(alpha: 0.08),
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kTeal,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontFamily: 'Jakarta',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kTeal,
        side: const BorderSide(color: kTeal, width: 1.4),
        textStyle: const TextStyle(
          fontFamily: 'Jakarta',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kTeal,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: kTeal,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: kTeal.withValues(alpha: 0.14),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    dialogTheme: const DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(color: Colors.grey.shade200, thickness: 1),
  );
}

/// Dark twin of [buildTheme]: same Jakarta type and shapes, surfaces and
/// text remapped so every screen stays readable without touching widgets.
ThemeData buildDarkTheme() {
  const bg = Color(0xFF0F1513);
  final scheme = ColorScheme.fromSeed(
    seedColor: kTealBright,
    secondary: kAmber,
    brightness: Brightness.dark,
    surface: const Color(0xFF151C1A),
  );
  final baseText = Typography.englishLike2021.apply(
    fontFamily: 'Jakarta',
    bodyColor: Colors.white,
    displayColor: Colors.white,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    useMaterial3: true,
    fontFamily: 'Jakarta',
    fontFamilyFallback: const ['Rubik'],
    textTheme: baseText.copyWith(
      titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodySmall: baseText.bodySmall?.copyWith(color: Colors.white70),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleTextStyle: const TextStyle(
        fontFamily: 'Jakarta',
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: Colors.black.withValues(alpha: 0.4),
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: const TextStyle(
          fontFamily: 'Jakarta',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        textStyle: const TextStyle(
          fontFamily: 'Jakarta',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHighest,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    dialogTheme: const DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// Logo mark mirroring the launcher icon.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 110});
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kTealBright, kTealDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: kTeal.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'M',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.55,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

Color tradeColor(String trade) {
  const palette = [
    Color(0xFF0F766E),
    Color(0xFF1D4ED8),
    Color(0xFF7C3AED),
    Color(0xFFB45309),
    Color(0xFFBE123C),
    Color(0xFF0E7490),
  ];
  final h = trade.toLowerCase().codeUnits.fold(0, (a, c) => a + c);
  return palette[h % palette.length];
}

class TradeChip extends StatelessWidget {
  const TradeChip({super.key, required this.trade});
  final String trade;
  @override
  Widget build(BuildContext context) {
    final c = vivid(context, tradeColor(trade));
    final label = MetaCache.label(trade, lang: Strings.lang(context));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final map = {
      'open': dark ? Colors.blue.shade300 : Colors.blue,
      'accepted': dark ? Colors.orange.shade300 : Colors.orange.shade800,
      'completed': dark ? Colors.green.shade300 : Colors.green.shade700,
      'cancelled': Colors.grey,
    };
    final c = map[status] ?? Colors.grey;
    final label = {
      'open': 'status_open',
      'accepted': 'status_accepted',
      'completed': 'status_completed',
      'cancelled': 'status_cancelled',
      'client': 'role_client',
      'craftsman': 'role_craftsman',
    }[status];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        (label != null ? Strings.t(context, label) : status).toUpperCase(),
        style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}

/// Centered error + retry, used instead of an endless spinner.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: muted(context)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text(Strings.t(context, 'retry')),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar circle with the user's initial.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({super.key, required this.name, this.radius = 20});
  final String name;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    final c = vivid(context, tradeColor(name));
    return CircleAvatar(
      radius: radius,
      backgroundColor: c.withValues(alpha: 0.15),
      child: Text(
        initial,
        style: TextStyle(color: c, fontWeight: FontWeight.bold),
      ),
    );
  }
}

String shortTime(String? iso) {
  if (iso == null) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  } catch (_) {
    return '';
  }
}

/// Star rating display (supports halves).
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.value, this.size = 16});
  final double value;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            value >= i - 0.25
                ? Icons.star
                : value >= i - 0.75
                ? Icons.star_half
                : Icons.star_border,
            size: size,
            color: Colors.amber.shade700,
          ),
      ],
    );
  }
}

/// Network image with placeholder + error state (feed-friendly).
class NetImage extends StatelessWidget {
  const NetImage({super.key, required this.url, this.height = 170});
  final String url;
  final double height;
  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (c, child, progress) => progress == null
            ? child
            : Container(
                height: height,
                color: softBg(context),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
        errorBuilder: (c, e, s) => Container(
          height: 90,
          color: softBg(context),
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        ),
      ),
    );
  }
}

// ---------- Landing ----------

class LandingScreen extends StatefulWidget {
  const LandingScreen({
    super.key,
    required this.session,
    required this.api,
    required this.locale,
  });
  final Session session;
  final ApiClient api;
  final AppLocale locale;
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool? serverOk;
  bool checking = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      checking = true;
    });
    final ok = await widget.api.ping();
    if (!mounted) return;
    setState(() {
      serverOk = ok;
      checking = false;
    });
  }

  void _go(bool login) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AuthScreen(session: widget.session, initialIsLogin: login),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Brand header.
              Expanded(
                flex: 5,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF14B8A6), Color(0xFF0B4F48)],
                    ),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(32),
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const LogoMark(size: 92),
                        const SizedBox(height: 12),
                        Text(
                          'Mossaid',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          Strings.t(context, 'tagline'),
                          style: TextStyle(
                            color: Color(0xD9FFFFFF),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Actions sheet.
              Expanded(
                flex: 6,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
                  child: Column(
                    children: [
                      Text(
                        Strings.t(context, 'landing_sub'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _LandingPerk(
                            icon: Icons.search_outlined,
                            label: Strings.t(context, 'perk_discover'),
                          ),
                          _LandingPerk(
                            icon: Icons.chat_bubble_outline,
                            label: Strings.t(context, 'perk_chat'),
                          ),
                          _LandingPerk(
                            icon: Icons.star_outline,
                            label: Strings.t(context, 'perk_rated'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => _go(true),
                          child: Text(
                            Strings.t(context, 'login'),
                            style: const TextStyle(fontSize: 17),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _go(false),
                          child: Text(
                            Strings.t(context, 'create_account'),
                            style: const TextStyle(fontSize: 17),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: softBg(context),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (checking)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              Icon(
                                serverOk == true ? Icons.wifi : Icons.wifi_off,
                                size: 18,
                                color: serverOk == true
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                checking
                                    ? Strings.t(context, 'checking_server')
                                    : serverOk == true
                                    ? Strings.t(context, 'server_ok')
                                    : Strings.t(context, 'server_down'),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 18),
                              tooltip: Strings.t(context, 'retry'),
                              onPressed: _check,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'v$kAppVersion',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Mode toggle floats over the brand header (white icon).
          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: const ThemeToggleButton(color: Colors.white),
            ),
          ),
          // Language menu (other corner).
          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            left: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: const LanguageMenuButton(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Auth ----------

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.session,
    this.initialIsLogin = true,
  });
  final Session session;
  final bool initialIsLogin;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  String role = 'client';
  bool showPassword = false;
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final city = TextEditingController();
  final trade = TextEditingController();
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    isLogin = widget.initialIsLogin;
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    city.dispose();
    trade.dispose();
    super.dispose();
  }

  String? _emailError(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return Strings.t(context, 'v_email');
    if (!t.contains('@') || !t.contains('.'))
      return Strings.t(context, 'v_email_bad');
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() {
      busy = true;
      error = null;
    });
    final err = await widget.session.auth(
      isLogin: isLogin,
      name: name.text.trim(),
      email: email.text.trim(),
      password: password.text,
      role: role,
      city: city.text.trim().isEmpty ? null : city.text.trim(),
      trade: !isLogin && role == 'craftsman' && trade.text.trim().isNotEmpty
          ? trade.text.trim()
          : null,
    );
    if (!mounted) return;
    setState(() {
      busy = false;
      error = err;
    });
    // Success: register already signs the user in (token saved), so leave
    // the form and reveal the home screen (Jobs tab) underneath.
    if (err == null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isLogin
              ? Strings.t(context, 'welcome_back')
              : Strings.t(context, 'join_title'),
        ),
        actions: const [LanguageMenuButton(), ThemeToggleButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const LogoMark(size: 72),
                  const SizedBox(height: 12),
                  Text(
                    isLogin
                        ? Strings.t(context, 'login_blurb')
                        : Strings.t(context, 'register_blurb'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: true,
                        label: Text(Strings.t(context, 'segment_login')),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text(Strings.t(context, 'segment_register')),
                      ),
                    ],
                    selected: {isLogin},
                    onSelectionChanged: (s) =>
                        setState(() => isLogin = s.first),
                  ),
                  const SizedBox(height: 14),
                  if (!isLogin) ...[
                    TextFormField(
                      controller: name,
                      decoration: InputDecoration(
                        labelText: Strings.t(context, 'full_name'),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? Strings.t(context, 'v_name')
                          : null,
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'client',
                          label: Text(Strings.t(context, 'role_client')),
                        ),
                        ButtonSegment(
                          value: 'craftsman',
                          label: Text(Strings.t(context, 'role_craftsman')),
                        ),
                      ],
                      selected: {role},
                      onSelectionChanged: (s) => setState(() => role = s.first),
                    ),
                    const SizedBox(height: 10),
                    if (role == 'craftsman')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextFormField(
                          controller: trade,
                          decoration: InputDecoration(
                            labelText: Strings.t(context, 'trade_label'),
                            prefixIcon: Icon(Icons.handyman_outlined),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    TextFormField(
                      controller: city,
                      decoration: InputDecoration(
                        labelText: Strings.t(context, 'city_optional'),
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextFormField(
                    controller: email,
                    decoration: InputDecoration(
                      labelText: Strings.t(context, 'email'),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: _emailError,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: password,
                    decoration: InputDecoration(
                      labelText: isLogin
                          ? Strings.t(context, 'password')
                          : Strings.t(context, 'password_min'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => showPassword = !showPassword),
                      ),
                    ),
                    obscureText: !showPassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) {
                      if ((v ?? '').isEmpty)
                        return Strings.t(context, 'v_password');
                      if (!isLogin && v!.length < 8) {
                        return Strings.t(context, 'v_password_min');
                      }
                      return null;
                    },
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              error!,
                              style: TextStyle(color: Colors.red.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy ? null : _submit,
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isLogin
                                ? Strings.t(context, 'btn_login')
                                : Strings.t(context, 'btn_create'),
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() => isLogin = !isLogin),
                    child: Text(
                      isLogin
                          ? Strings.t(context, 'no_account')
                          : Strings.t(context, 'have_account'),
                    ),
                  ),
                  if (isLogin)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ForgotPasswordScreen(
                                  api: widget.session.api,
                                ),
                              ),
                            ),
                      child: Text(Strings.t(context, 'forgot')),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Home ----------

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.api,
    required this.theme,
    required this.locale,
  });
  final Session session;
  final ApiClient api;
  final AppTheme theme;
  final AppLocale locale;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  int unread = 0;

  bool get isCraft => widget.session.isCraftsman;

  @override
  void initState() {
    super.initState();
    // Clients land on Discover, craftsmen on Requests.
    tab = isCraft ? 1 : 0;
    MetaCache.ensure(widget.api);
    _refreshUnread();
  }

  Future<void> _refreshUnread() async {
    try {
      final n = await widget.api.notifications();
      if (!mounted) return;
      setState(() => unread = (n['unread_count'] as num?)?.toInt() ?? 0);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Client: Discover · My Jobs · Alerts · Account
    // Craftsman: My Work · Requests · Alerts · Account
    final pages = isCraft
        ? [
            PostsTab(api: widget.api, isCraftsman: true, onlyMine: true),
            JobsTab(
              api: widget.api,
              session: widget.session,
              mode: JobMode.requests,
            ),
            NotificationsTab(
              api: widget.api,
              session: widget.session,
              onRead: _refreshUnread,
            ),
            AccountTab(
              session: widget.session,
              api: widget.api,
              theme: widget.theme,
              locale: widget.locale,
            ),
          ]
        : [
            PostsTab(api: widget.api, isCraftsman: false),
            JobsTab(
              api: widget.api,
              session: widget.session,
              mode: JobMode.mine,
            ),
            NotificationsTab(
              api: widget.api,
              session: widget.session,
              onRead: _refreshUnread,
            ),
            AccountTab(
              session: widget.session,
              api: widget.api,
              theme: widget.theme,
              locale: widget.locale,
            ),
          ];
    final labels = isCraft
        ? [
            Strings.t(context, 'tab_mywork'),
            Strings.t(context, 'tab_requests'),
            Strings.t(context, 'tab_alerts'),
            Strings.t(context, 'tab_account'),
          ]
        : [
            Strings.t(context, 'tab_discover'),
            Strings.t(context, 'tab_jobs'),
            Strings.t(context, 'tab_alerts'),
            Strings.t(context, 'tab_account'),
          ];
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14, top: 8, bottom: 8),
          child: InitialAvatar(name: widget.session.name ?? '?', radius: 20),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Strings.t(context, 'salam', {'name': widget.session.name ?? ''}),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              labels[tab],
              style: TextStyle(fontSize: 13, color: muted(context)),
            ),
          ],
        ),
        actions: const [LanguageMenuButton(), ThemeToggleButton()],
      ),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) {
          setState(() => tab = i);
          if (i == 2) _refreshUnread();
        },
        destinations: [
          NavigationDestination(
            icon: Icon(isCraft ? Icons.store_outlined : Icons.explore_outlined),
            label: labels[0],
          ),
          NavigationDestination(
            icon: const Icon(Icons.work_outline),
            label: labels[1],
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
            label: labels[2],
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            label: labels[3],
          ),
        ],
      ),
    );
  }
}

List<dynamic> _pageItems(Map<String, dynamic> page) =>
    (page['data'] as List?) ?? [];

class PostsTab extends StatefulWidget {
  const PostsTab({
    super.key,
    required this.api,
    required this.isCraftsman,
    this.onlyMine = false,
  });
  final ApiClient api;
  final bool isCraftsman;
  final bool onlyMine;
  @override
  State<PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<PostsTab> {
  List<dynamic> items = [];
  bool loading = true;
  String? error;
  String? trade;
  final search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final page = await widget.api.posts(
        q: search.text.trim().isEmpty ? null : search.text.trim(),
        trade: trade,
        mine: widget.onlyMine,
      );
      if (!mounted) return;
      setState(() => items = _pageItems(page));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: search,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: Strings.t(context, 'search_crafts'),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
            ],
          ),
        ),
        if (!widget.onlyMine && MetaCache.trades.isNotEmpty)
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6, top: 8),
                  child: ChoiceChip(
                    label: Text(Strings.t(context, 'chip_all')),
                    selected: trade == null,
                    onSelected: (_) => setState(() {
                      trade = null;
                      _load();
                    }),
                  ),
                ),
                for (final t in MetaCache.trades)
                  Padding(
                    padding: const EdgeInsets.only(right: 6, top: 8),
                    child: ChoiceChip(
                      avatar: Icon(
                        tradeIcon((t['icon'] ?? '') as String),
                        size: 16,
                      ),
                      label: Text(
                        MetaCache.label(
                          (t['slug'] ?? '') as String,
                          lang: Strings.lang(context),
                        ),
                      ),
                      selected: trade == t['slug'],
                      onSelected: (_) => setState(() {
                        trade = t['slug'] as String;
                        _load();
                      }),
                    ),
                  ),
              ],
            ),
          ),
        if (widget.isCraftsman)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: Text(Strings.t(context, 'publish_work')),
                onPressed: () async {
                  final created = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostFormScreen(api: widget.api),
                    ),
                  );
                  if (created == true) _load();
                },
              ),
            ),
          ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      Strings.t(context, 'no_posts'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final p = items[i] as Map<String, dynamic>;
                      return PostCard(
                        api: widget.api,
                        post: p,
                        onOpen: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PostDetailScreen(
                                api: widget.api,
                                postId: (p['id'] as num).toInt(),
                              ),
                            ),
                          );
                          _load();
                        },
                        onProfile: (id) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CraftsmanProfileScreen(
                                api: widget.api,
                                userId: id,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class PostFormScreen extends StatefulWidget {
  const PostFormScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<PostFormScreen> createState() => _PostFormScreenState();
}

class _PostFormScreenState extends State<PostFormScreen> {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final desc = TextEditingController();
  final tradeFree = TextEditingController(text: 'painter');
  final cityFree = TextEditingController();
  final price = TextEditingController();
  String? trade;
  String? city;
  List<String> photos = [];
  bool uploading = false;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    trade = MetaCache.trades.any((t) => t['slug'] == 'painter')
        ? 'painter'
        : null;
  }

  Future<void> _pickPhoto() async {
    if (photos.length >= 3 || uploading) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked == null) return;
      setState(() => uploading = true);
      final url = await widget.api.uploadPhoto(picked.path, folder: 'posts');
      if (!mounted) return;
      setState(() => photos = [...photos, url]);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => error = e is ApiException ? e.message : 'Photo failed: $e',
      );
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _publish() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final finalTrade = (trade ?? tradeFree.text).trim();
    if (finalTrade.isEmpty) {
      setState(() => error = Strings.t(context, 'f_trade_required'));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.createPost({
        'title': title.text.trim(),
        'description': desc.text.trim(),
        'trade': finalTrade,
        if ((city ?? cityFree.text).trim().isNotEmpty)
          'city': (city ?? cityFree.text).trim(),
        if (price.text.trim().isNotEmpty)
          'price_hint': int.tryParse(price.text.trim()),
        if (photos.isNotEmpty) 'photos': photos,
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tradeSlugs = MetaCache.trades
        .map((t) => (t['slug'] ?? '') as String)
        .where((s) => s.isNotEmpty)
        .toList();
    final cityOptions = MetaCache.cities;
    return Scaffold(
      appBar: AppBar(
        title: Text(Strings.t(context, 'showcase_title')),
        actions: const [LanguageMenuButton(), ThemeToggleButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photos (max 3).
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final url in photos)
                      Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                url,
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 4,
                            top: 4,
                            child: InkWell(
                              onTap: () => setState(
                                () => photos = photos
                                    .where((u) => u != url)
                                    .toList(),
                              ),
                              child: const CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.black54,
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    InkWell(
                      onTap: _pickPhoto,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: softBg(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: uploading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined),
                                  Text(
                                    Strings.t(context, 'f_add_photo'),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: title,
                decoration: InputDecoration(
                  labelText: Strings.t(context, 'f_title'),
                  prefixIcon: Icon(Icons.title_outlined),
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? Strings.t(context, 'f_title_hint_post')
                    : null,
              ),
              const SizedBox(height: 10),
              if (tradeSlugs.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: tradeSlugs.contains(trade) ? trade : null,
                  decoration: InputDecoration(
                    labelText: Strings.t(context, 'f_trade'),
                    prefixIcon: Icon(Icons.handyman_outlined),
                  ),
                  items: [
                    for (final s in tradeSlugs)
                      DropdownMenuItem(
                        value: s,
                        child: Text(
                          MetaCache.label(s, lang: Strings.lang(context)),
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => trade = v),
                  validator: (v) =>
                      v == null ? Strings.t(context, 'f_pick_trade') : null,
                )
              else
                TextFormField(
                  controller: tradeFree,
                  decoration: InputDecoration(
                    labelText: Strings.t(context, 'f_trade_hint'),
                    prefixIcon: Icon(Icons.handyman_outlined),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? Strings.t(context, 'f_trade_required')
                      : null,
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: cityOptions.isNotEmpty
                        ? DropdownButtonFormField<String>(
                            initialValue: cityOptions.contains(city)
                                ? city
                                : null,
                            decoration: InputDecoration(
                              labelText: Strings.t(context, 'f_city'),
                              prefixIcon: Icon(Icons.location_city_outlined),
                            ),
                            items: [
                              for (final c in cityOptions)
                                DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    MetaCache.cityLabel(
                                      c,
                                      lang: Strings.lang(context),
                                    ),
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() => city = v),
                          )
                        : TextFormField(
                            controller: cityFree,
                            decoration: InputDecoration(
                              labelText: Strings.t(context, 'f_city'),
                              prefixIcon: Icon(Icons.location_city_outlined),
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: price,
                      decoration: InputDecoration(
                        labelText: Strings.t(context, 'f_price'),
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: desc,
                decoration: InputDecoration(
                  labelText: Strings.t(context, 'f_desc_work'),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (v) => (v ?? '').trim().length < 10
                    ? Strings.t(context, 'f_desc_min')
                    : null,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    error!,
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : _publish,
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(Strings.t(context, 'f_publish')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.api, required this.postId});
  final ApiClient api;
  final int postId;
  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Map<String, dynamic>? post;
  List<dynamic> comments = [];
  bool liked = false;
  int photoIndex = 0;
  String? error;
  final comment = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await widget.api.postDetail(widget.postId);
      final c = await widget.api.comments(widget.postId);
      if (!mounted) return;
      setState(() {
        post = p;
        comments = c;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => error = e is ApiException ? e.message : 'Could not load post: $e',
      );
    }
  }

  void _fail(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e is ApiException ? e.message : 'Failed: $e')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (post == null) {
      return Scaffold(
        appBar: AppBar(actions: const [ThemeToggleButton()]),
        body: Center(
          child: error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: Text(Strings.t(context, 'retry')),
                        onPressed: _load,
                      ),
                    ],
                  ),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    final u = (post!['user'] as Map?) ?? {};
    final photos = ((post!['photos'] as List?) ?? [])
        .map((e) => '$e')
        .where((e) => e.isNotEmpty)
        .toList();
    final rating = ((u['rating_avg'] as num?)?.toDouble() ?? 0);
    final ratingCount = ((u['rating_count'] as num?)?.toInt() ?? 0);
    return Scaffold(
      appBar: AppBar(
        title: Text(post!['title'] ?? Strings.t(context, 'post_word')),
        actions: const [LanguageMenuButton(), ThemeToggleButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Craftsman card → profile.
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              final id = (u['id'] as num?)?.toInt();
              if (id != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CraftsmanProfileScreen(api: widget.api, userId: id),
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: softBg(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  InitialAvatar(name: (u['name'] ?? '?') as String),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u['name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (ratingCount > 0)
                          Row(
                            children: [
                              RatingStars(value: rating, size: 14),
                              Text(
                                ' $rating ($ratingCount)',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          )
                        else
                          Text(
                            Strings.t(context, 'new_craftsman'),
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                  TradeChip(trade: (post!['trade'] ?? '') as String),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            post!['description'] ?? '',
            style: const TextStyle(fontSize: 15),
          ),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: PageView(
                onPageChanged: (i) => setState(() => photoIndex = i),
                children: [
                  for (final url in photos) NetImage(url: url, height: 220),
                ],
              ),
            ),
            Text(
              'Photo ${photoIndex + 1} of ${photos.length} — swipe →',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton.tonalIcon(
                icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
                label: Text('❤ ${post!['likes_count'] ?? 0}'),
                onPressed: () async {
                  try {
                    final r = await widget.api.toggleLike(widget.postId);
                    if (!mounted) return;
                    setState(() {
                      liked = r['liked'] == true;
                      post!['likes_count'] = r['likes_count'];
                    });
                  } catch (e) {
                    _fail(e);
                  }
                },
              ),
            ],
          ),
          const Divider(),
          Text(
            Strings.t(context, 'comments_title', {'n': '${comments.length}'}),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final c in comments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InitialAvatar(
                    name:
                        ((((c as Map)['user'] as Map?) ?? {})['name'] ?? '?')
                            as String,
                    radius: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: softBg(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (((c['user'] as Map?) ?? {})['name'] ?? ''),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(c['body'] ?? ''),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: comment,
                  decoration: InputDecoration(
                    hintText: Strings.t(context, 'comment_hint'),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () async {
                  if (comment.text.trim().isEmpty) return;
                  try {
                    await widget.api.addComment(
                      widget.postId,
                      comment.text.trim(),
                    );
                    comment.clear();
                    _load();
                  } catch (e) {
                    _fail(e);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------- Jobs ----------

enum JobMode { all, mine, requests }

class JobsTab extends StatefulWidget {
  const JobsTab({
    super.key,
    required this.api,
    required this.session,
    this.mode = JobMode.all,
  });
  final ApiClient api;
  final Session session;
  final JobMode mode;
  @override
  State<JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<JobsTab> {
  List<dynamic> items = [];
  bool loading = true;
  String? error;
  String status = '';
  final search = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.mode == JobMode.requests) status = 'open';
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final page = await widget.api.jobs(
        q: search.text.trim().isEmpty ? null : search.text.trim(),
        status: status.isEmpty ? null : status,
        mine: widget.mode == JobMode.mine,
      );
      if (!mounted) return;
      setState(() {
        items = _pageItems(page);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e is ApiException ? e.message : 'Could not load jobs: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCraft = widget.session.isCraftsman;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: search,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: Strings.t(context, 'search_jobs'),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
            ],
          ),
        ),
        if (widget.mode != JobMode.requests)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in ['', 'open', 'accepted', 'completed'])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(
                        s.isEmpty
                            ? Strings.t(context, 'status_all')
                            : Strings.t(context, 'status_$s'),
                      ),
                      selected: status == s,
                      onSelected: (_) {
                        setState(() => status = s);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
        if (!isCraft && widget.mode == JobMode.mine)
          Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: Text(Strings.t(context, 'post_job_btn')),
                onPressed: () async {
                  final created = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => JobFormScreen(api: widget.api),
                    ),
                  );
                  if (created == true) _load();
                },
              ),
            ),
          ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: Text(Strings.t(context, 'retry')),
                          onPressed: _load,
                        ),
                      ],
                    ),
                  ),
                )
              : items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      'No jobs yet — clients, post the first request! 👆',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final j = items[i] as Map<String, dynamic>;
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => JobDetailScreen(
                                  api: widget.api,
                                  session: widget.session,
                                  jobId: (j['id'] as num).toInt(),
                                ),
                              ),
                            );
                            _load();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        j['title'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    StatusChip(
                                      status: (j['status'] ?? 'open') as String,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  (j['description'] ?? '') as String,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: muted(context)),
                                ),
                                if ((j['cover_photo'] ?? '') != '') ...[
                                  const SizedBox(height: 10),
                                  NetImage(
                                    url: (j['cover_photo'] ?? '') as String,
                                    height: 140,
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    TradeChip(
                                      trade: (j['trade'] ?? '') as String,
                                    ),
                                    if ((j['city'] ?? '') != '') ...[
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.place_outlined,
                                        size: 14,
                                        color: muted(context),
                                      ),
                                      Text(
                                        MetaCache.cityLabel(
                                          j['city'],
                                          lang: Strings.lang(context),
                                        ),
                                        style: TextStyle(
                                          color: muted(context),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    if (j['budget'] != null)
                                      Text(
                                        '${j['budget']} DZD',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: proTeal(context),
                                        ),
                                      ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right,
                                      color: muted(context),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class JobFormScreen extends StatefulWidget {
  const JobFormScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<JobFormScreen> createState() => _JobFormScreenState();
}

class _JobFormScreenState extends State<JobFormScreen> {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final desc = TextEditingController();
  final tradeFree = TextEditingController(text: 'painter');
  final cityFree = TextEditingController();
  final budget = TextEditingController();
  String? tradeSel;
  String? citySel;
  String? coverUrl;
  bool uploading = false;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    tradeSel = MetaCache.trades.any((t) => t['slug'] == 'painter')
        ? 'painter'
        : null;
  }

  Future<void> _pickCover() async {
    if (uploading) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked == null) return;
      setState(() => uploading = true);
      final url = await widget.api.uploadPhoto(picked.path, folder: 'jobs');
      if (!mounted) return;
      setState(() => coverUrl = url);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => error = e is ApiException ? e.message : 'Photo failed: $e',
      );
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _post() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final finalTrade = (tradeSel ?? tradeFree.text).trim();
    if (finalTrade.isEmpty) {
      setState(() => error = Strings.t(context, 'f_trade_required'));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.createJob({
        'title': title.text.trim(),
        'description': desc.text.trim(),
        'trade': finalTrade,
        if ((citySel ?? cityFree.text).trim().isNotEmpty)
          'city': (citySel ?? cityFree.text).trim(),
        if (budget.text.trim().isNotEmpty)
          'budget': int.tryParse(budget.text.trim()),
        if (coverUrl != null) 'cover_photo': coverUrl,
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tradeSlugs = MetaCache.trades
        .map((t) => (t['slug'] ?? '') as String)
        .where((s) => s.isNotEmpty)
        .toList();
    final cityOptions = MetaCache.cities;
    return Scaffold(
      appBar: AppBar(
        title: Text(Strings.t(context, 'job_title')),
        actions: const [LanguageMenuButton(), ThemeToggleButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover photo (optional).
              InkWell(
                onTap: _pickCover,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: softBg(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: coverUrl != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                coverUrl!,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              right: 6,
                              top: 6,
                              child: InkWell(
                                onTap: () => setState(() => coverUrl = null),
                                child: const CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.black54,
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : uploading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_a_photo_outlined, size: 32),
                            const SizedBox(height: 4),
                            Text(Strings.t(context, 'f_cover')),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: title,
                decoration: InputDecoration(
                  labelText: Strings.t(context, 'f_need'),
                  prefixIcon: Icon(Icons.work_outline),
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? Strings.t(context, 'f_title_required')
                    : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: tradeSlugs.isNotEmpty
                        ? DropdownButtonFormField<String>(
                            initialValue: tradeSlugs.contains(tradeSel)
                                ? tradeSel
                                : null,
                            decoration: InputDecoration(
                              labelText: Strings.t(context, 'f_need_trade'),
                              prefixIcon: Icon(Icons.handyman_outlined),
                            ),
                            items: [
                              for (final s in tradeSlugs)
                                DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    MetaCache.label(
                                      s,
                                      lang: Strings.lang(context),
                                    ),
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() => tradeSel = v),
                            validator: (v) => v == null
                                ? Strings.t(context, 'f_required')
                                : null,
                          )
                        : TextFormField(
                            controller: tradeFree,
                            decoration: InputDecoration(
                              labelText: Strings.t(context, 'f_need_trade'),
                              prefixIcon: Icon(Icons.handyman_outlined),
                            ),
                            validator: (v) => (v ?? '').trim().isEmpty
                                ? Strings.t(context, 'f_required')
                                : null,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: cityOptions.isNotEmpty
                        ? DropdownButtonFormField<String>(
                            initialValue: cityOptions.contains(citySel)
                                ? citySel
                                : null,
                            decoration: InputDecoration(
                              labelText: Strings.t(context, 'f_city'),
                              prefixIcon: Icon(Icons.location_city_outlined),
                            ),
                            items: [
                              for (final c in cityOptions)
                                DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    MetaCache.cityLabel(
                                      c,
                                      lang: Strings.lang(context),
                                    ),
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() => citySel = v),
                          )
                        : TextFormField(
                            controller: cityFree,
                            decoration: InputDecoration(
                              labelText: Strings.t(context, 'f_city'),
                              prefixIcon: Icon(Icons.location_city_outlined),
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: budget,
                decoration: InputDecoration(
                  labelText: Strings.t(context, 'f_budget'),
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: desc,
                decoration: InputDecoration(
                  labelText: Strings.t(context, 'f_job_details'),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (v) => (v ?? '').trim().length < 10
                    ? Strings.t(context, 'f_job_details_min')
                    : null,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    error!,
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : _post,
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(Strings.t(context, 'f_post_job')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({
    super.key,
    required this.api,
    required this.session,
    required this.jobId,
  });
  final ApiClient api;
  final Session session;
  final int jobId;
  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  Map<String, dynamic>? job;
  List<dynamic> messages = [];
  Timer? poll;
  final msg = TextEditingController();
  String? notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await widget.api.jobShow(widget.jobId);
      if (!mounted) return;
      setState(() {
        job = res;
        notice = null;
      });
      _startPollIfOpen();
    } catch (e) {
      if (!mounted) return;
      setState(
        () => notice = e is ApiException ? e.message : 'Could not load job: $e',
      );
    }
  }

  void _startPollIfOpen() {
    poll?.cancel();
    final st = job?['status'];
    if (st == 'accepted' || st == 'completed') {
      _poll();
      poll = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
    }
  }

  Future<void> _poll() async {
    try {
      final lastId = messages.isEmpty
          ? null
          : (messages.last['id'] as num).toInt();
      final fresh = await widget.api.messages(widget.jobId, afterId: lastId);
      if (fresh.isNotEmpty) setState(() => messages = [...messages, ...fresh]);
      if (lastId == null) {
        final all = await widget.api.messages(widget.jobId);
        setState(() => messages = all);
      }
    } catch (_) {
      /* chat closed or error — keep quiet */
    }
  }

  @override
  void dispose() {
    poll?.cancel();
    super.dispose();
  }

  Future<void> _action(String action) async {
    try {
      final updated = await widget.api.jobAction(widget.jobId, action);
      setState(() {
        job = updated;
        notice = null;
      });
      _startPollIfOpen();
    } on ApiException catch (e) {
      setState(() => notice = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (job == null) {
      return Scaffold(
        appBar: AppBar(actions: const [ThemeToggleButton()]),
        body: Center(
          child: notice != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(notice!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: Text(Strings.t(context, 'retry')),
                        onPressed: _load,
                      ),
                    ],
                  ),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    final st = job!['status'] as String? ?? 'open';
    final isCraft = widget.session.isCraftsman;
    final chatOpen = st == 'accepted' || st == 'completed';
    return Scaffold(
      appBar: AppBar(
        title: Text(job!['title'] ?? Strings.t(context, 'job_word')),
        actions: const [LanguageMenuButton(), ThemeToggleButton()],
      ),
      body: Column(
        children: [
          JobTimeline(status: st),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TradeChip(trade: (job!['trade'] ?? '') as String),
                      const SizedBox(width: 8),
                      StatusChip(status: st),
                      const Spacer(),
                      if (job!['budget'] != null)
                        Text(
                          '${job!['budget']} DZD',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: proTeal(context),
                            fontSize: 16,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(job!['description'] ?? ''),
                  if ((job!['city'] ?? '') != '') ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: muted(context),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          MetaCache.cityLabel(
                            job!['city'],
                            lang: Strings.lang(context),
                          ),
                          style: TextStyle(color: muted(context)),
                        ),
                      ],
                    ),
                  ],
                  if (notice != null) ...[
                    const SizedBox(height: 6),
                    Text(notice!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (isCraft && st == 'open')
                        FilledButton.icon(
                          icon: const Icon(Icons.handshake_outlined),
                          label: Text(Strings.t(context, 'accept_open_chat')),
                          onPressed: () => _action('accept'),
                        ),
                      if (!isCraft && st == 'accepted')
                        FilledButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(Strings.t(context, 'mark_completed')),
                          onPressed: () => _action('complete'),
                        ),
                      if (st == 'open' || st == 'accepted')
                        OutlinedButton(
                          onPressed: () => _action('cancel'),
                          child: Text(Strings.t(context, 'cancel')),
                        ),
                      if (!isCraft && st == 'completed')
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.star_outline),
                          label: Text(Strings.t(context, 'rate_craftsman')),
                          onPressed: () async {
                            final done = await showDialog<bool>(
                              context: context,
                              builder: (_) => ReviewDialog(
                                api: widget.api,
                                jobId: widget.jobId,
                              ),
                            );
                            if (done == true) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    Strings.t(context, 'thanks_review'),
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Chat exists only after client + craftsman agree (accepted).
          // Before that, no chat UI at all — not even a locked box.
          if (chatOpen) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text(
                    Strings.t(context, 'chat_live'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              child: messages.isEmpty
                  ? Center(child: Text(Strings.t(context, 'say_salam')))
                  : ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final m = messages[i] as Map<String, dynamic>;
                        final mine =
                            (m['sender_id'] as num).toInt().toString() ==
                            widget.session.user?['id'].toString();
                        final sender = (m['sender'] as Map?) ?? {};
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: mine ? kTeal : softBg(context),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(mine ? 16 : 4),
                                bottomRight: Radius.circular(mine ? 4 : 16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: mine
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!mine && (sender['name'] ?? '') != '')
                                  Text(
                                    sender['name'],
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: muted(context),
                                    ),
                                  ),
                                Text(
                                  m['body'] ?? '',
                                  style: TextStyle(
                                    color: mine
                                        ? Colors.white
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  shortTime(m['created_at'] as String?),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: mine
                                        ? Colors.white70
                                        : muted(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: msg,
                      decoration: InputDecoration(
                        hintText: Strings.t(context, 'message_hint'),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () async {
                      if (msg.text.trim().isEmpty) return;
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final sent = await widget.api.sendMessage(
                          widget.jobId,
                          msg.text.trim(),
                        );
                        msg.clear();
                        if (!mounted) return;
                        setState(() => messages = [...messages, sent]);
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              e is ApiException ? e.message : 'Send failed: $e',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AccountTab extends StatelessWidget {
  const AccountTab({
    super.key,
    required this.session,
    required this.api,
    required this.theme,
    required this.locale,
  });
  final Session session;
  final ApiClient api;
  final AppTheme theme;
  final AppLocale locale;
  @override
  Widget build(BuildContext context) {
    final u = session.user ?? {};
    final isCraft = (u['role'] ?? '') == 'craftsman';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                InitialAvatar(name: (u['name'] ?? '?') as String, radius: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        u['email'] ?? '',
                        style: TextStyle(color: muted(context)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          StatusChip(status: (u['role'] ?? '') as String),
                          if ((u['city'] ?? '') != '') ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.place_outlined,
                              size: 14,
                              color: muted(context),
                            ),
                            Text(
                              MetaCache.cityLabel(
                                u['city'],
                                lang: Strings.lang(context),
                              ),
                              style: TextStyle(
                                color: muted(context),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isCraft && (u['trade'] ?? '') != '')
          Card(
            child: ListTile(
              leading: Icon(Icons.handyman_outlined, color: proTeal(context)),
              title: Text(Strings.t(context, 'my_trade')),
              subtitle: Text(u['trade']),
            ),
          ),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.edit_outlined, color: proTeal(context)),
                title: Text(Strings.t(context, 'edit_title')),
                subtitle: Text(Strings.t(context, 'edit_profile_sub')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ProfileEditScreen(session: session, api: api),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.work_outline, color: proTeal(context)),
                title: Text(Strings.t(context, 'my_jobs')),
                subtitle: Text(
                  isCraft
                      ? Strings.t(context, 'my_jobs_sub_craft')
                      : Strings.t(context, 'my_jobs_sub_client'),
                ),
              ),
              ListTile(
                leading: Icon(Icons.store_outlined, color: proTeal(context)),
                title: Text(Strings.t(context, 'marketplace')),
                subtitle: Text(
                  isCraft
                      ? Strings.t(context, 'marketplace_sub_craft')
                      : Strings.t(context, 'marketplace_sub_client'),
                ),
              ),
              ListTile(
                leading: Icon(
                  Theme.of(context).brightness == Brightness.dark
                      ? Icons.wb_sunny_outlined
                      : Icons.dark_mode_outlined,
                  color: proTeal(context),
                ),
                title: Text(Strings.t(context, 'appearance')),
                subtitle: Text(
                  Theme.of(context).brightness == Brightness.dark
                      ? Strings.t(context, 'appearance_dark')
                      : Strings.t(context, 'appearance_light'),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => theme.toggle(context),
              ),
              ListTile(
                leading: Icon(Icons.language_outlined, color: proTeal(context)),
                title: Text(Strings.t(context, 'language')),
                subtitle: Text(
                  locale.code == 'ar'
                      ? 'العربية'
                      : locale.code == 'fr'
                      ? 'Français'
                      : locale.code == 'en'
                      ? 'English'
                      : Strings.t(context, 'language_sub'),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final pick = await showDialog<String>(
                    context: context,
                    builder: (c) => SimpleDialog(
                      title: Text(Strings.t(context, 'language')),
                      children: [
                        for (final opt in const ['ar', 'fr', 'en', 'system'])
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(c, opt),
                            child: Row(
                              children: [
                                if (locale.code == opt)
                                  const Icon(Icons.check, size: 18),
                                Text(
                                  opt == 'ar'
                                      ? 'العربية'
                                      : opt == 'fr'
                                      ? 'Français'
                                      : opt == 'en'
                                      ? 'English'
                                      : 'System / Système / النظام',
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                  if (pick != null) await locale.set(pick);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout, color: Colors.red),
          label: Text(
            Strings.t(context, 'logout'),
            style: const TextStyle(color: Colors.red),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.red.shade200),
          ),
          onPressed: () => session.logout(),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Mossaid v$kAppVersion',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------- Craftsman profile ----------

class CraftsmanProfileScreen extends StatefulWidget {
  const CraftsmanProfileScreen({
    super.key,
    required this.api,
    required this.userId,
  });
  final ApiClient api;
  final int userId;
  @override
  State<CraftsmanProfileScreen> createState() => _CraftsmanProfileScreenState();
}

class _CraftsmanProfileScreenState extends State<CraftsmanProfileScreen> {
  Map<String, dynamic>? data;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await widget.api.craftsmanProfile(widget.userId);
      if (!mounted) return;
      setState(() {
        data = d;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => error = e is ApiException ? e.message : 'Could not load: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return Scaffold(
        appBar: AppBar(actions: const [ThemeToggleButton()]),
        body: Center(
          child: error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : const CircularProgressIndicator(),
        ),
      );
    }
    final c = (data!['craftsman'] as Map?) ?? {};
    final reviews = ((data!['reviews'] as Map?) ?? {})['data'] as List? ?? [];
    final rating = ((c['rating_avg'] as num?)?.toDouble() ?? 0);
    final count = ((c['rating_count'] as num?)?.toInt() ?? 0);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          (c['name'] ?? Strings.t(context, 'role_craftsman')) as String,
        ),
        actions: const [LanguageMenuButton(), ThemeToggleButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  InitialAvatar(name: (c['name'] ?? '?') as String, radius: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if ((c['city'] ?? '') != '')
                          Text(
                            MetaCache.cityLabel(
                              c['city'],
                              lang: Strings.lang(context),
                            ),
                            style: TextStyle(color: muted(context)),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            RatingStars(value: rating),
                            Text(
                              count > 0
                                  ? ' $rating ($count reviews)'
                                  : ' No reviews yet',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if ((c['trade'] ?? '') != '')
                    TradeChip(trade: c['trade'] as String),
                ],
              ),
            ),
          ),
          if ((c['bio'] ?? '') != '')
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(c['bio']),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              Strings.t(context, 'reviews_title', {'n': '$count'}),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (reviews.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(Strings.t(context, 'no_reviews')),
              ),
            ),
          for (final r in reviews)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        RatingStars(
                          value: ((r as Map)['rating'] as num).toDouble(),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          ((((r)['reviewer'] as Map?) ?? {})['name'] ?? ''),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (((r)['comment'] ?? '') != '')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(r['comment']),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------- Review dialog ----------

class ReviewDialog extends StatefulWidget {
  const ReviewDialog({super.key, required this.api, required this.jobId});
  final ApiClient api;
  final int jobId;
  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  int rating = 5;
  final comment = TextEditingController();
  String? error;
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(Strings.t(context, 'rate_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  icon: Icon(
                    i <= rating ? Icons.star : Icons.star_border,
                    color: Colors.amber.shade700,
                    size: 32,
                  ),
                  onPressed: () => setState(() => rating = i),
                ),
            ],
          ),
          TextField(
            controller: comment,
            decoration: InputDecoration(
              hintText: Strings.t(context, 'rate_hint'),
            ),
            maxLines: 3,
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: Text(Strings.t(context, 'later')),
        ),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  try {
                    await widget.api.createReview(
                      widget.jobId,
                      rating,
                      comment.text.trim().isEmpty ? null : comment.text.trim(),
                    );
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (e) {
                    if (!mounted) return;
                    setState(
                      () => error = e is ApiException ? e.message : '$e',
                    );
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(Strings.t(context, 'send_review')),
        ),
      ],
    );
  }
}

// ---------- Notifications ----------

/// Localized (title, body) for a notification. The username stays exactly
/// as the user wrote it; everything else follows the app language.
/// Falls back to the server strings for old rows without `actor_name`.
(String, String) _notifText(
  BuildContext context,
  String type,
  Map<dynamic, dynamic> data,
  String fallbackTitle,
  String fallbackBody,
) {
  final actor = '${data['actor_name'] ?? ''}';
  if (actor.isEmpty) return (fallbackTitle, fallbackBody);
  switch (type) {
    case 'job.accepted':
      return (
        Strings.t(context, 'nt_accepted_t', {'actor': actor}),
        Strings.t(context, 'nt_accepted_b'),
      );
    case 'message.received':
      return (
        Strings.t(context, 'nt_message_t', {'actor': actor}),
        fallbackBody, // the user's own words — keep as written
      );
    case 'job.completed':
      return (
        Strings.t(context, 'nt_completed_t'),
        Strings.t(context, 'nt_completed_b', {'actor': actor}),
      );
    case 'review.received':
      return (
        Strings.t(context, 'nt_review_t', {
          'rating': '${data['rating'] ?? ''}',
        }),
        Strings.t(context, 'nt_review_b', {'actor': actor}),
      );
    default:
      return (fallbackTitle, fallbackBody);
  }
}

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({
    super.key,
    required this.api,
    required this.session,
    required this.onRead,
  });
  final ApiClient api;
  final Session session;
  final VoidCallback onRead;
  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  List<dynamic> items = [];
  bool loading = true;
  String? error;

  static const _icons = {
    'job.accepted': Icons.handshake_outlined,
    'job.completed': Icons.check_circle_outline,
    'message.received': Icons.chat_bubble_outline,
    'review.received': Icons.star_outline,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final n = await widget.api.notifications();
      if (!mounted) return;
      setState(() => items = _pageItems(n));
    } catch (e) {
      if (!mounted) return;
      setState(
        () => error = e is ApiException ? e.message : 'Could not load: $e',
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await widget.api.markNotificationsRead();
      widget.onRead();
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Text(
                Strings.t(context, 'alerts_title'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.done_all, size: 18),
                label: Text(Strings.t(context, 'mark_all_read')),
                onPressed: _markAllRead,
              ),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
            ],
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : items.isEmpty
              ? Center(child: Text(Strings.t(context, 'no_alerts')))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final n = items[i] as Map<String, dynamic>;
                      final unread = n['read_at'] == null;
                      final payload = (n['data'] as Map?) ?? const {};
                      final jobId = payload['job_id'] as num?;
                      final text = _notifText(
                        context,
                        (n['type'] ?? '') as String,
                        payload,
                        '${n['title'] ?? ''}',
                        '${n['body'] ?? ''}',
                      );
                      return Card(
                        color: unread
                            ? proTeal(context).withValues(alpha: 0.08)
                            : null,
                        child: ListTile(
                          leading: Icon(
                            _icons[(n['type'] ?? '') as String] ??
                                Icons.notifications_outlined,
                            color: proTeal(context),
                          ),
                          title: Text(
                            text.$1,
                            style: TextStyle(
                              fontWeight: unread
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            '${text.$2}\n${shortTime(n['created_at'] as String?)}',
                          ),
                          isThreeLine: true,
                          trailing: unread
                              ? Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: proTeal(context),
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                          onTap: () async {
                            // Job-related alerts jump straight to the job.
                            if (jobId != null) {
                              try {
                                await widget.api.markNotificationsRead([
                                  (n['id'] as num).toInt(),
                                ]);
                              } catch (_) {}
                              widget.onRead();
                              if (!context.mounted) return;
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => JobDetailScreen(
                                    api: widget.api,
                                    session: widget.session,
                                    jobId: jobId.toInt(),
                                  ),
                                ),
                              );
                              _load();
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ---------- Profile edit ----------

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({
    super.key,
    required this.session,
    required this.api,
  });
  final Session session;
  final ApiClient api;
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final formKey = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.session.user?['name']);
  late final phone = TextEditingController(text: widget.session.user?['phone']);
  late final city = TextEditingController(text: widget.session.user?['city']);
  late final bio = TextEditingController(text: widget.session.user?['bio']);
  String? trade;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    trade = widget.session.user?['trade'] as String?;
  }

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final updated = await widget.api.updateProfile({
        'name': name.text.trim(),
        if (phone.text.trim().isNotEmpty) 'phone': phone.text.trim(),
        if (city.text.trim().isNotEmpty) 'city': city.text.trim(),
        if (bio.text.trim().isNotEmpty) 'bio': bio.text.trim(),
        if (widget.session.isCraftsman && (trade ?? '').isNotEmpty)
          'trade': trade,
      });
      widget.session.updateUser(updated);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e is ApiException ? e.message : '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tradeOptions = [
      ...MetaCache.trades.map((t) => (t['slug'] ?? '') as String),
      if (trade != null && !MetaCache.trades.any((t) => t['slug'] == trade))
        trade!,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(Strings.t(context, 'edit_title')),
        actions: const [LanguageMenuButton(), ThemeToggleButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: name,
                decoration: InputDecoration(
                  labelText: Strings.t(context, 'full_name'),
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? Strings.t(context, 'v_name')
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: phone,
                decoration: InputDecoration(
                  labelText: Strings.t(context, 'f_phone'),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              if (widget.session.isCraftsman)
                DropdownButtonFormField<String>(
                  initialValue: tradeOptions.contains(trade) ? trade : null,
                  decoration: InputDecoration(
                    labelText: Strings.t(context, 'f_trade'),
                  ),
                  items: [
                    for (final s in tradeOptions)
                      DropdownMenuItem(
                        value: s,
                        child: Text(
                          MetaCache.label(s, lang: Strings.lang(context)),
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => trade = v),
                )
              else
                TextFormField(
                  controller: city,
                  decoration: InputDecoration(
                    labelText: Strings.t(context, 'f_city'),
                  ),
                ),
              if (widget.session.isCraftsman) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: city,
                  decoration: InputDecoration(
                    labelText: Strings.t(context, 'f_city'),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextFormField(
                controller: bio,
                decoration: InputDecoration(
                  labelText: Strings.t(context, 'f_bio'),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : _save,
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(Strings.t(context, 'save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Forgot password ----------

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int step = 0; // 0 = email, 1 = code + new password
  final email = TextEditingController();
  final code = TextEditingController();
  final password = TextEditingController();
  String? info;
  String? error;
  bool busy = false;

  Future<void> _send() async {
    if (email.text.trim().isEmpty || !email.text.contains('@')) {
      setState(() => error = Strings.t(context, 'v_email_bad'));
      return;
    }
    setState(() {
      busy = true;
      error = null;
      info = null;
    });
    try {
      final r = await widget.api.forgotPassword(email.text.trim());
      if (!mounted) return;
      setState(() {
        busy = false;
        step = 1;
        // v1 backend returns the code (no mail wired yet).
        info = r['code'] != null
            ? Strings.t(context, 'code_is', {'code': '${r['code']}'})
            : Strings.t(context, 'code_sent');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = e is ApiException ? e.message : '$e';
      });
    }
  }

  Future<void> _reset() async {
    if (code.text.trim().length != 6) {
      setState(() => error = Strings.t(context, 'code_hint'));
      return;
    }
    if (password.text.length < 8) {
      setState(() => error = Strings.t(context, 'pass_hint'));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.resetPassword(
        email.text.trim(),
        code.text.trim(),
        password.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Strings.t(context, 'password_changed'))),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = e is ApiException ? e.message : '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Strings.t(context, 'reset_title')),
        actions: const [LanguageMenuButton(), ThemeToggleButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (step == 0) ...[
              Text(Strings.t(context, 'reset_step1')),
              const SizedBox(height: 12),
              TextField(
                controller: email,
                decoration: InputDecoration(
                  labelText: Strings.t(context, 'email'),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ] else ...[
              if (info != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: proTeal(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(info!),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: code,
                decoration: InputDecoration(
                  labelText: Strings.t(context, 'code_label'),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              TextField(
                controller: password,
                decoration: InputDecoration(
                  labelText: Strings.t(context, 'new_password'),
                ),
                obscureText: true,
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : (step == 0 ? _send : _reset),
              child: Text(
                step == 0
                    ? Strings.t(context, 'send_code')
                    : Strings.t(context, 'change_password'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Marketplace post card (image-first) ----------

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.api,
    required this.post,
    required this.onOpen,
    required this.onProfile,
  });
  final ApiClient api;
  final Map<String, dynamic> post;
  final VoidCallback onOpen;
  final ValueChanged<int> onProfile;

  @override
  Widget build(BuildContext context) {
    final p = post;
    final u = (p['user'] as Map?) ?? {};
    final photos = ((p['photos'] as List?) ?? [])
        .map((e) => '$e')
        .where((e) => e.isNotEmpty)
        .toList();
    final rating = ((u['rating_avg'] as num?)?.toDouble() ?? 0);
    final ratingCount = ((u['rating_count'] as num?)?.toInt() ?? 0);
    final commentCount = ((p['comments_count'] as num?)?.toInt() ?? 0);
    final trade = (p['trade'] ?? '') as String;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (photos.isNotEmpty)
              Stack(
                children: [
                  Image.network(
                    photos.first,
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (c, child, progress) => progress == null
                        ? child
                        : Container(
                            height: 190,
                            color: softBg(context),
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                    errorBuilder: (c, e, s) => Container(
                      height: 120,
                      color: softBg(context),
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.3),
                          ],
                          stops: const [0.65, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        MetaCache.label(trade, lang: Strings.lang(context)),
                        style: const TextStyle(
                          color: kTeal,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  if (photos.length > 1)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.photo_library_outlined,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${photos.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              )
            else
              Container(
                height: 84,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      tradeColor(trade).withValues(alpha: 0.9),
                      tradeColor(trade).withValues(alpha: 0.55),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        tradeIcon(_tradeIconKey(trade)),
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      MetaCache.label(trade, lang: Strings.lang(context)),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          final id = (u['id'] as num?)?.toInt();
                          if (id != null) onProfile(id);
                        },
                        child: InitialAvatar(
                          name: (u['name'] ?? '?') as String,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['title'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '${u['name'] ?? ''}${(p['city'] ?? '') != '' ? ' · ${MetaCache.cityLabel(p['city'], lang: Strings.lang(context))}' : ''}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: muted(context),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (ratingCount > 0) ...[
                                  const SizedBox(width: 6),
                                  RatingStars(value: rating, size: 13),
                                  Text(
                                    ' ($ratingCount)',
                                    style: TextStyle(
                                      color: muted(context),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    (p['description'] ?? '') as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: muted(context), fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.favorite,
                        size: 16,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${p['likes_count'] ?? 0}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 16,
                        color: muted(context),
                      ),
                      const SizedBox(width: 4),
                      Text('$commentCount'),
                      const Spacer(),
                      if ((p['price_hint']) != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: kTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${p['price_hint']} DZD',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: proTeal(context),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _tradeIconKey(String slug) {
  for (final t in MetaCache.trades) {
    if (t['slug'] == slug) return (t['icon'] ?? 'work') as String;
  }
  return 'work';
}

// ---------- Landing perk chip ----------

class _LandingPerk extends StatelessWidget {
  const _LandingPerk({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: kTeal.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: proTeal(context), size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
