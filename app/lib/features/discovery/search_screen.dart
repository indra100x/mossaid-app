import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../l10n/app_localizations.dart';
import 'craftsman_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _tradeCtrl = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  String? _err;

  Future<void> _search() async {
    setState(() { _loading = true; _err = null; });
    try {
      final api = ApiClient();
      final res = await api.get('/api/v1/discovery/search', query: {
        if (_tradeCtrl.text.isNotEmpty) 'trade': _tradeCtrl.text.trim(),
        'limit': '20',
      });
      setState(() => _items = List<Map<String, dynamic>>.from(res['items'] as List));
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() { super.initState(); _search(); }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _tradeCtrl, decoration: InputDecoration(hintText: l10n.searchTradeHint))),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _loading ? null : _search, child: Text(l10n.searchButton)),
              ],
            ),
          ),
          if (_err != null) Text(_err!, style: const TextStyle(color: Colors.red)),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _items.isEmpty
                ? Center(child: Text(l10n.searchNoResults))
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final it = _items[i];
                      return ListTile(
                        title: Text(it['name'] ?? it['trades'].toString()),
                        subtitle: Text('trades: ${it['trades']} • ${it['hourly_rate'] ?? ''} DZD'),
                        trailing: Text('${it['rating_avg']}★'),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CraftsmanProfileScreen(data: it))),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
