import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';
import 'session.dart';

void main() {
  final api = ApiClient();
  runApp(MossaidSimple(session: Session(api)..load(), api: api));
}

/// Update this when releasing a new APK so we can tell builds apart.
const String kAppVersion = '1.0.2 (build 3)';

const Color kTeal = Color(0xFF0F766E);
const Color kTealLight = Color(0xFF14B8A6);
const Color kAmber = Color(0xFFF59E0B);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kTeal, secondary: kAmber);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(centerTitle: false),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      ),
    ),
    chipTheme: const ChipThemeData(
      padding: EdgeInsets.symmetric(horizontal: 8),
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
          colors: [kTealLight, Color(0xFF0D6E64)],
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
    final c = tradeColor(trade);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        trade,
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
    final map = {
      'open': Colors.blue,
      'accepted': Colors.orange.shade800,
      'completed': Colors.green.shade700,
      'cancelled': Colors.grey,
    };
    final c = map[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
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
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
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
    return CircleAvatar(
      radius: radius,
      backgroundColor: tradeColor(name).withValues(alpha: 0.15),
      child: Text(
        initial,
        style: TextStyle(color: tradeColor(name), fontWeight: FontWeight.bold),
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

class MossaidSimple extends StatelessWidget {
  const MossaidSimple({super.key, required this.session, required this.api});
  final Session session;
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (_, __) => MaterialApp(
        title: 'Mossaid',
        theme: buildTheme(),
        home: !session.loaded
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : session.loggedIn
            ? HomeScreen(session: session, api: api)
            : LandingScreen(session: session, api: api),
      ),
    );
  }
}

// ---------- Landing ----------

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key, required this.session, required this.api});
  final Session session;
  final ApiClient api;
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
      body: Column(
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
              child: const SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LogoMark(size: 92),
                    SizedBox(height: 12),
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
                      'Trusted craftsmen, one tap away',
                      style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 15),
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
                  const Text(
                    'Clients post jobs · Craftsmen showcase work · Chat opens after accept.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _go(true),
                      child: const Text(
                        'Login',
                        style: TextStyle(fontSize: 17),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _go(false),
                      child: const Text(
                        'Create account',
                        style: TextStyle(fontSize: 17),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Server reachability — answers "is the app stuck or is it the network?"
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (checking)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            serverOk == true ? Icons.wifi : Icons.wifi_off,
                            size: 18,
                            color: serverOk == true ? Colors.green : Colors.red,
                          ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            checking
                                ? 'Checking server…'
                                : serverOk == true
                                ? 'Server reachable ✓'
                                : 'Server NOT reachable — check Wi-Fi / server',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 18),
                          tooltip: 'Recheck',
                          onPressed: _check,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'v$kAppVersion',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
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
    if (t.isEmpty) return 'Email is required';
    if (!t.contains('@') || !t.contains('.')) return 'Enter a valid email';
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
      appBar: AppBar(title: Text(isLogin ? 'Welcome back' : 'Join Mossaid')),
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
                        ? 'Login to find craftsmen or manage your jobs.'
                        : 'Create your account — clients post jobs, craftsmen get discovered.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Login')),
                      ButtonSegment(value: false, label: Text('Register')),
                    ],
                    selected: {isLogin},
                    onSelectionChanged: (s) =>
                        setState(() => isLogin = s.first),
                  ),
                  const SizedBox(height: 14),
                  if (!isLogin) ...[
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'client', label: Text('Client')),
                        ButtonSegment(
                          value: 'craftsman',
                          label: Text('Craftsman'),
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
                          decoration: const InputDecoration(
                            labelText: 'Trade (painter, plumber…)',
                            prefixIcon: Icon(Icons.handyman_outlined),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    TextFormField(
                      controller: city,
                      decoration: const InputDecoration(
                        labelText: 'City (optional)',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextFormField(
                    controller: email,
                    decoration: const InputDecoration(
                      labelText: 'Email',
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
                          ? 'Password'
                          : 'Password (min 8 chars)',
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
                      if ((v ?? '').isEmpty) return 'Password is required';
                      if (!isLogin && v!.length < 8) {
                        return 'At least 8 characters';
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
                            isLogin ? 'Login' : 'Create account',
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
                          ? "No account? Create one"
                          : 'Already registered? Login',
                    ),
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
  const HomeScreen({super.key, required this.session, required this.api});
  final Session session;
  final ApiClient api;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Land on Jobs: clients track requests, craftsmen find work.
  int tab = 1;
  static const titles = ['Portfolio posts', 'Jobs', 'Account'];
  @override
  Widget build(BuildContext context) {
    final pages = [
      PostsTab(api: widget.api, isCraftsman: widget.session.isCraftsman),
      JobsTab(api: widget.api, session: widget.session),
      AccountTab(session: widget.session),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Salam, ${widget.session.name ?? ''} 👋',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              titles[tab],
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.store), label: 'Posts'),
          NavigationDestination(icon: Icon(Icons.work), label: 'Jobs'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Account'),
        ],
      ),
    );
  }
}

List<dynamic> _pageItems(Map<String, dynamic> page) =>
    (page['data'] as List?) ?? [];

class PostsTab extends StatefulWidget {
  const PostsTab({super.key, required this.api, required this.isCraftsman});
  final ApiClient api;
  final bool isCraftsman;
  @override
  State<PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<PostsTab> {
  List<dynamic> items = [];
  bool loading = true;
  String? error;
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
      );
      setState(() => items = _pageItems(page));
    } on ApiException catch (e) {
      setState(() => error = e.message);
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search painter, plumber…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
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
                label: const Text('Publish your work'),
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
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Text(
                      'No posts yet — craftsmen, publish the first one! 👆',
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
                      final u = (p['user'] as Map?) ?? {};
                      final commentCount =
                          (p['comments_count'] as num?)?.toInt() ?? 0;
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
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
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    InitialAvatar(
                                      name: (u['name'] ?? '?') as String,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p['title'] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            '${u['name'] ?? ''}${(p['city'] ?? '') != '' ? ' · ${p['city']}' : ''}',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TradeChip(
                                      trade: (p['trade'] ?? '') as String,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  (p['description'] ?? '') as String,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey.shade800),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.favorite,
                                      size: 16,
                                      color: Colors.red.shade400,
                                    ),
                                    const SizedBox(width: 4),
                                    Text('${p['likes_count'] ?? 0}'),
                                    const SizedBox(width: 16),
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 16,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 4),
                                    Text('$commentCount'),
                                    if ((p['price_hint']) != null) ...[
                                      const Spacer(),
                                      Text(
                                        '${p['price_hint']} DZD',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: kTeal,
                                        ),
                                      ),
                                    ],
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
  final trade = TextEditingController(text: 'painter');
  final city = TextEditingController();
  final price = TextEditingController();
  String? error;
  bool busy = false;

  Future<void> _publish() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.createPost({
        'title': title.text.trim(),
        'description': desc.text.trim(),
        'trade': trade.text.trim(),
        if (city.text.trim().isNotEmpty) 'city': city.text.trim(),
        if (price.text.trim().isNotEmpty)
          'price_hint': int.tryParse(price.text.trim()),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Showcase your work')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.title_outlined),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Give your post a title' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: trade,
                decoration: const InputDecoration(
                  labelText: 'Trade (painter, plumber, electrician…)',
                  prefixIcon: Icon(Icons.handyman_outlined),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Trade is required' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: city,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: price,
                      decoration: const InputDecoration(
                        labelText: 'Price (DZD)',
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
                decoration: const InputDecoration(
                  labelText: 'Describe your work, experience, materials…',
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (v) => (v ?? '').trim().length < 10
                    ? 'A few more details help clients trust you'
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
                    : const Text('Publish post'),
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
        appBar: AppBar(),
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
                        label: const Text('Retry'),
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
    return Scaffold(
      appBar: AppBar(title: Text(post!['title'] ?? 'Post')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            '${u['name'] ?? ''} · ${post!['trade'] ?? ''} · ${post!['city'] ?? ''}',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(post!['description'] ?? ''),
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
            'Comments (${comments.length})',
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
                        color: Colors.grey.shade100,
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
                  decoration: const InputDecoration(hintText: 'Add a comment…'),
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

class JobsTab extends StatefulWidget {
  const JobsTab({super.key, required this.api, required this.session});
  final ApiClient api;
  final Session session;
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
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search jobs…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final s in ['', 'open', 'accepted', 'completed'])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(s.isEmpty ? 'all' : s),
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
        if (!isCraft)
          Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Post a job request'),
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
                          label: const Text('Retry'),
                          onPressed: _load,
                        ),
                      ],
                    ),
                  ),
                )
              : items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
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
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
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
                                        color: Colors.grey.shade500,
                                      ),
                                      Text(
                                        j['city'],
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    if (j['budget'] != null)
                                      Text(
                                        '${j['budget']} DZD',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: kTeal,
                                        ),
                                      ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey.shade400,
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
  final trade = TextEditingController(text: 'painter');
  final city = TextEditingController();
  final budget = TextEditingController();
  String? error;
  bool busy = false;

  Future<void> _post() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.createJob({
        'title': title.text.trim(),
        'description': desc.text.trim(),
        'trade': trade.text.trim(),
        if (city.text.trim().isNotEmpty) 'city': city.text.trim(),
        if (budget.text.trim().isNotEmpty)
          'budget': int.tryParse(budget.text.trim()),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Describe your job')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'What do you need? (e.g. Repaint living room)',
                  prefixIcon: Icon(Icons.work_outline),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: trade,
                      decoration: const InputDecoration(
                        labelText: 'Trade needed',
                        prefixIcon: Icon(Icons.handyman_outlined),
                      ),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: city,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: budget,
                decoration: const InputDecoration(
                  labelText: 'Budget DZD (optional)',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: desc,
                decoration: const InputDecoration(
                  labelText: 'Details: size, materials, timing…',
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (v) => (v ?? '').trim().length < 10
                    ? 'Add a few details so craftsmen can respond'
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
                    : const Text('Post job request'),
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
        appBar: AppBar(),
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
                        label: const Text('Retry'),
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
      appBar: AppBar(title: Text(job!['title'] ?? 'Job')),
      body: Column(
        children: [
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: kTeal,
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
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          job!['city'],
                          style: TextStyle(color: Colors.grey.shade600),
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
                          label: const Text('Accept job → open chat'),
                          onPressed: () => _action('accept'),
                        ),
                      if (!isCraft && st == 'accepted')
                        FilledButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Mark completed'),
                          onPressed: () => _action('complete'),
                        ),
                      if (st == 'open' || st == 'accepted')
                        OutlinedButton(
                          onPressed: () => _action('cancel'),
                          child: const Text('Cancel'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(
                  chatOpen
                      ? 'Chat (updates every 5s)'
                      : 'Chat opens after a craftsman accepts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          Expanded(
            child: !chatOpen
                ? const Center(child: Text('🔒 No chat yet.'))
                : messages.isEmpty
                ? const Center(child: Text('Say salam! 👋'))
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
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
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
                            color: mine ? kTeal : Colors.grey.shade200,
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
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              Text(
                                m['body'] ?? '',
                                style: TextStyle(
                                  color: mine ? Colors.white : Colors.black87,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                shortTime(m['created_at'] as String?),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: mine
                                      ? Colors.white70
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (chatOpen)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: msg,
                      decoration: const InputDecoration(
                        hintText: 'Message…',
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
      ),
    );
  }
}

class AccountTab extends StatelessWidget {
  const AccountTab({super.key, required this.session});
  final Session session;
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
                        style: TextStyle(color: Colors.grey.shade600),
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
                              color: Colors.grey.shade500,
                            ),
                            Text(
                              u['city'],
                              style: TextStyle(
                                color: Colors.grey.shade600,
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
              leading: const Icon(Icons.handyman_outlined, color: kTeal),
              title: const Text('My trade'),
              subtitle: Text(u['trade']),
            ),
          ),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.work_outline, color: kTeal),
                title: const Text('My jobs'),
                subtitle: Text(
                  isCraft
                      ? 'Accepted work and requests appear here'
                      : 'Track your requests and chats here',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.store_outlined, color: kTeal),
                title: const Text('Marketplace'),
                subtitle: Text(
                  isCraft
                      ? 'Your portfolio posts live under Posts'
                      : 'Browse craftsmen under Posts',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text('Logout', style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.red.shade200),
          ),
          onPressed: () => session.logout(),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Mossaid v$kAppVersion',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
