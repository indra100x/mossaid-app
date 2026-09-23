import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../../l10n/app_localizations.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  WebSocketChannel? _channel;
  bool _connected = false;
  String? _err;
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _connect();
  }

  Future<void> _loadHistory() async {
    try {
      final token = await AuthStorage().getAccess();
      final api = ApiClient();
      final res = await api.get('/api/v1/chat/${widget.bookingId}/messages', token: token);
      // Our ApiClient wraps list as {'data': list}
      List list;
      if (res.containsKey('data')) {
        list = res['data'] as List;
      } else {
        // Fallback: try via direct http handling — but ApiClient already handles
        list = [];
      }
      setState(() => _messages.addAll(List<Map<String, dynamic>>.from(list)));
      // mark read
      await api.post('/api/v1/chat/${widget.bookingId}/read', {}, token: token);
    } catch (e) {
      setState(() => _err = e.toString());
    }
  }

  Future<void> _connect() async {
    try {
      final token = await AuthStorage().getAccess();
      final base = const String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8000');
      final wsBase = base.replaceFirst('http', 'ws');
      final uri = Uri.parse('$wsBase/api/v1/chat/ws/${widget.bookingId}?token=$token');
      final ch = WebSocketChannel.connect(uri);
      setState(() { _channel = ch; _connected = true; });
      ch.stream.listen((data) {
        try {
          final decoded = jsonDecode(data as String);
          if (decoded is Map<String, dynamic> && decoded.containsKey('content')) {
            setState(() => _messages.add(decoded));
          }
        } catch (_) {
          setState(() => _messages.add({'content': data.toString(), 'sender_id': 'unknown'}));
        }
      }, onDone: () => setState(() => _connected = false), onError: (_) => setState(() => _connected = false));
    } catch (e) {
      setState(() => _err = e.toString());
    }
  }

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _channel == null) return;
    _channel!.sink.add(jsonEncode({'content': text}));
    _msgCtrl.clear();
    setState(() => _typing = false);
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.chatTitle), actions: [if (_connected) const Icon(Icons.circle, color: Colors.green, size: 12) else const Icon(Icons.circle, color: Colors.red, size: 12)]),
      body: Column(
        children: [
          if (_err != null) Padding(padding: const EdgeInsets.all(8), child: Text(_err!, style: const TextStyle(color: Colors.red))),
          if (_typing) Padding(padding: const EdgeInsets.all(4), child: Text(l10n.chatTyping, style: const TextStyle(color: Colors.grey))),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                return ListTile(
                  title: Text(m['content'] ?? ''),
                  subtitle: Text(m['sent_at'] ?? ''),
                  trailing: m['read_at'] != null ? Text(l10n.chatRead, style: const TextStyle(fontSize: 10, color: Colors.blue)) : null,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _msgCtrl, decoration: InputDecoration(hintText: l10n.chatPlaceholder), onChanged: (v) => setState(() => _typing = v.isNotEmpty))),
                IconButton(icon: const Icon(Icons.send), onPressed: _send),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
