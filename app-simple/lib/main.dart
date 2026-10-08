import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';
import 'session.dart';

void main() {
  final api = ApiClient();
  runApp(MossaidSimple(session: Session(api)..load(), api: api));
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
        title: 'Mossaid Simple',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: !session.loaded
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : session.loggedIn
                ? HomeScreen(session: session, api: api)
                : AuthScreen(session: session),
      ),
    );
  }
}

// ---------- Auth ----------

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.session});
  final Session session;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  String role = 'client';
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final city = TextEditingController();
  String? error;
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mossaid — crafts marketplace')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Login')),
                  ButtonSegment(value: false, label: Text('Register')),
                ],
                selected: {isLogin},
                onSelectionChanged: (s) =>
                    setState(() => isLogin = s.first),
              ),
              const SizedBox(height: 12),
              if (!isLogin) ...[
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'client', label: Text('Client')),
                    ButtonSegment(value: 'craftsman', label: Text('Craftsman')),
                  ],
                  selected: {role},
                  onSelectionChanged: (s) => setState(() => role = s.first),
                ),
                TextField(controller: city, decoration: const InputDecoration(labelText: 'City (optional)')),
              ],
              TextField(controller: email, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
              TextField(controller: password, decoration: const InputDecoration(labelText: 'Password (8+ chars)'), obscureText: true),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() { busy = true; error = null; });
                        final err = await widget.session.auth(
                          isLogin: isLogin,
                          name: name.text.trim(),
                          email: email.text.trim(),
                          password: password.text,
                          role: role,
                          city: city.text.trim().isEmpty ? null : city.text.trim(),
                        );
                        setState(() { busy = false; error = err; });
                      },
                child: Text(busy ? 'Please wait…' : (isLogin ? 'Login' : 'Create account')),
              ),
              const SizedBox(height: 8),
              const Text('Craftsmen publish portfolio posts · Clients post job requests · Chat opens after accept.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ]),
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
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      PostsTab(api: widget.api, isCraftsman: widget.session.isCraftsman),
      JobsTab(api: widget.api, session: widget.session),
      AccountTab(session: widget.session),
    ];
    return Scaffold(
      appBar: AppBar(title: Text('Salam ${widget.session.name ?? ''} 👋')),
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
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final page = await widget.api.posts(q: search.text.trim().isEmpty ? null : search.text.trim());
      setState(() => items = _pageItems(page));
    } on ApiException catch (e) {
      setState(() => error = e.message);
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          Expanded(child: TextField(controller: search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search painter, plumber…', border: OutlineInputBorder()))),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ]),
      ),
      if (widget.isCraftsman)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(width: double.infinity, child: OutlinedButton.icon(icon: const Icon(Icons.add), label: const Text('Publish your work'), onPressed: () async {
            final created = await Navigator.push(context, MaterialPageRoute(builder: (_) => PostFormScreen(api: widget.api)));
            if (created == true) _load();
          })),
        ),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text(error!))
                : items.isEmpty
                    ? const Center(child: Text('No posts yet — craftsmen, publish the first one!'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (_, i) {
                            final p = items[i] as Map<String, dynamic>;
                            final u = (p['user'] as Map?) ?? {};
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(child: Text(((u['name'] ?? '?') as String).substring(0, 1).toUpperCase())),
                                title: Text(p['title'] ?? ''),
                                subtitle: Text('${u['name'] ?? ''} · ${p['trade'] ?? ''} · ${p['city'] ?? ''}\n❤ ${p['likes_count'] ?? 0}'),
                                isThreeLine: true,
                                onTap: () async {
                                  await Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(api: widget.api, postId: (p['id'] as num).toInt())));
                                  _load();
                                },
                              ),
                            );
                          },
                        ),
                      ),
      ),
    ]);
  }
}

class PostFormScreen extends StatefulWidget {
  const PostFormScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<PostFormScreen> createState() => _PostFormScreenState();
}

class _PostFormScreenState extends State<PostFormScreen> {
  final title = TextEditingController();
  final desc = TextEditingController();
  final trade = TextEditingController(text: 'painter');
  final city = TextEditingController();
  String? error;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New post')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
          TextField(controller: trade, decoration: const InputDecoration(labelText: 'Trade (painter, plumber, electrician…)')),
          TextField(controller: city, decoration: const InputDecoration(labelText: 'City')),
          TextField(controller: desc, decoration: const InputDecoration(labelText: 'Describe your work'), maxLines: 4),
          if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          FilledButton(onPressed: () async {
            try {
              await widget.api.createPost({
                'title': title.text.trim(), 'description': desc.text.trim(),
                'trade': trade.text.trim(), if (city.text.trim().isNotEmpty) 'city': city.text.trim(),
              });
              if (context.mounted) Navigator.pop(context, true);
            } on ApiException catch (e) { setState(() => error = e.message); }
          }, child: const Text('Publish')),
        ]),
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
  final comment = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await widget.api.postDetail(widget.postId);
    final c = await widget.api.comments(widget.postId);
    setState(() { post = p; comments = c; });
  }

  @override
  Widget build(BuildContext context) {
    if (post == null) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    final u = (post!['user'] as Map?) ?? {};
    return Scaffold(
      appBar: AppBar(title: Text(post!['title'] ?? 'Post')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Text('${u['name'] ?? ''} · ${post!['trade'] ?? ''} · ${post!['city'] ?? ''}', style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        Text(post!['description'] ?? ''),
        const SizedBox(height: 8),
        Row(children: [
          FilledButton.tonalIcon(
            icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
            label: Text('❤ ${post!['likes_count'] ?? 0}'),
            onPressed: () async {
              final r = await widget.api.toggleLike(widget.postId);
              setState(() { liked = r['liked'] == true; post!['likes_count'] = r['likes_count']; });
            },
          ),
        ]),
        const Divider(),
        Text('Comments (${comments.length})', style: Theme.of(context).textTheme.titleMedium),
        for (final c in comments)
          ListTile(dense: true, leading: const Icon(Icons.comment), title: Text((c as Map)['body'] ?? ''), subtitle: Text(((c['user'] as Map?) ?? {})['name'] ?? '')),
        Row(children: [
          Expanded(child: TextField(controller: comment, decoration: const InputDecoration(hintText: 'Add a comment…'))),
          IconButton(icon: const Icon(Icons.send), onPressed: () async {
            if (comment.text.trim().isEmpty) return;
            await widget.api.addComment(widget.postId, comment.text.trim());
            comment.clear();
            _load();
          }),
        ]),
      ]),
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
  String status = '';
  final search = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => loading = true);
    final page = await widget.api.jobs(q: search.text.trim().isEmpty ? null : search.text.trim(), status: status.isEmpty ? null : status);
    setState(() { items = _pageItems(page); loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final isCraft = widget.session.isCraftsman;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          Expanded(child: TextField(controller: search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search jobs…', border: OutlineInputBorder()))),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ]),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final s in ['', 'open', 'accepted', 'completed'])
            Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(label: Text(s.isEmpty ? 'all' : s), selected: status == s, onSelected: (_) { setState(() => status = s); _load(); })),
        ]),
      ),
      if (!isCraft)
        Padding(padding: const EdgeInsets.all(8), child: SizedBox(width: double.infinity, child: OutlinedButton.icon(icon: const Icon(Icons.add), label: const Text('Post a job request'), onPressed: () async {
          final created = await Navigator.push(context, MaterialPageRoute(builder: (_) => JobFormScreen(api: widget.api)));
          if (created == true) _load();
        }))),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
                ? const Center(child: Text('No jobs yet.'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final j = items[i] as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: ListTile(
                            title: Text(j['title'] ?? ''),
                            subtitle: Text('${j['trade'] ?? ''} · ${j['city'] ?? ''} · ${j['status'] ?? ''}${j['budget'] != null ? ' · ${j['budget']} DZD' : ''}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailScreen(api: widget.api, session: widget.session, jobId: (j['id'] as num).toInt())));
                              _load();
                            },
                          ),
                        );
                      },
                    ),
                  ),
      ),
    ]);
  }
}

class JobFormScreen extends StatefulWidget {
  const JobFormScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<JobFormScreen> createState() => _JobFormScreenState();
}

class _JobFormScreenState extends State<JobFormScreen> {
  final title = TextEditingController();
  final desc = TextEditingController();
  final trade = TextEditingController(text: 'painter');
  final city = TextEditingController();
  final budget = TextEditingController();
  String? error;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New job request')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
          TextField(controller: trade, decoration: const InputDecoration(labelText: 'Trade needed')),
          TextField(controller: city, decoration: const InputDecoration(labelText: 'City')),
          TextField(controller: budget, decoration: const InputDecoration(labelText: 'Budget DZD (optional)'), keyboardType: TextInputType.number),
          TextField(controller: desc, decoration: const InputDecoration(labelText: 'Describe the job'), maxLines: 4),
          if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          FilledButton(onPressed: () async {
            try {
              await widget.api.createJob({
                'title': title.text.trim(), 'description': desc.text.trim(), 'trade': trade.text.trim(),
                if (city.text.trim().isNotEmpty) 'city': city.text.trim(),
                if (budget.text.trim().isNotEmpty) 'budget': int.tryParse(budget.text.trim()),
              });
              if (context.mounted) Navigator.pop(context, true);
            } on ApiException catch (e) { setState(() => error = e.message); }
          }, child: const Text('Post job')),
        ]),
      ),
    );
  }
}

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key, required this.api, required this.session, required this.jobId});
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
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final res = await widget.api.jobShow(widget.jobId);
    setState(() => job = res);
    _startPollIfOpen();
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
      final lastId = messages.isEmpty ? null : (messages.last['id'] as num).toInt();
      final fresh = await widget.api.messages(widget.jobId, afterId: lastId);
      if (fresh.isNotEmpty) setState(() => messages = [...messages, ...fresh]);
      if (lastId == null) {
        final all = await widget.api.messages(widget.jobId);
        setState(() => messages = all);
      }
    } catch (_) {/* chat closed or error — keep quiet */}
  }

  @override
  void dispose() { poll?.cancel(); super.dispose(); }

  Future<void> _action(String action) async {
    try {
      final updated = await widget.api.jobAction(widget.jobId, action);
      setState(() { job = updated; notice = null; });
      _startPollIfOpen();
    } on ApiException catch (e) { setState(() => notice = e.message); }
  }

  @override
  Widget build(BuildContext context) {
    if (job == null) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    final st = job!['status'] as String? ?? 'open';
    final isCraft = widget.session.isCraftsman;
    final chatOpen = st == 'accepted' || st == 'completed';
    return Scaffold(
      appBar: AppBar(title: Text(job!['title'] ?? 'Job')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${job!['trade'] ?? ''} · ${job!['city'] ?? ''} · status: $st', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 6),
            Text(job!['description'] ?? ''),
            if (notice != null) Text(notice!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              if (isCraft && st == 'open') FilledButton(onPressed: () => _action('accept'), child: const Text('Accept job → open chat')),
              if (!isCraft && st == 'accepted') FilledButton(onPressed: () => _action('complete'), child: const Text('Mark completed')),
              if (st == 'open' || st == 'accepted') OutlinedButton(onPressed: () => _action('cancel'), child: const Text('Cancel')),
            ]),
          ]),
        ),
        const Divider(),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [Text(chatOpen ? 'Chat (updates every 5s)' : 'Chat opens after a craftsman accepts', style: Theme.of(context).textTheme.titleMedium)])),
        Expanded(
          child: !chatOpen
              ? const Center(child: Text('🔒 No chat yet.'))
              : messages.isEmpty
                  ? const Center(child: Text('Say salam! 👋'))
                  : ListView.builder(itemCount: messages.length, itemBuilder: (_, i) {
                      final m = messages[i] as Map<String, dynamic>;
                      final mine = (m['sender_id'] as num).toInt().toString() == widget.session.user?['id'].toString();
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: mine ? Colors.teal.shade100 : Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                          child: Text(m['body'] ?? '')),
                      );
                    }),
        ),
        if (chatOpen)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Expanded(child: TextField(controller: msg, decoration: const InputDecoration(hintText: 'Message…', border: OutlineInputBorder()))),
              IconButton(icon: const Icon(Icons.send), onPressed: () async {
                if (msg.text.trim().isEmpty) return;
                final sent = await widget.api.sendMessage(widget.jobId, msg.text.trim());
                msg.clear();
                setState(() => messages = [...messages, sent]);
              }),
            ]),
          ),
      ]),
    );
  }
}

class AccountTab extends StatelessWidget {
  const AccountTab({super.key, required this.session});
  final Session session;
  @override
  Widget build(BuildContext context) {
    final u = session.user ?? {};
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(u['name'] ?? '', style: Theme.of(context).textTheme.headlineSmall),
      Text('${u['email'] ?? ''} · ${u['role'] ?? ''}'),
      if ((u['city'] ?? '') != '') Text('📍 ${u['city']}'),
      const SizedBox(height: 16),
      OutlinedButton.icon(icon: const Icon(Icons.logout), label: const Text('Logout'), onPressed: () => session.logout()),
    ]);
  }
}
