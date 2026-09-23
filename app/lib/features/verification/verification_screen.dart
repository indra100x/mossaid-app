import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../../l10n/app_localizations.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  String _docType = 'id';
  final _fileCtrl = TextEditingController(text: 'id_card.pdf');
  List<Map<String, dynamic>> _docs = [];
  bool _loading = false;
  String? _err;
  String? _success;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = await AuthStorage().getAccess();
      final docs = await _fetchDocs(token);
      if (mounted) setState(() => _docs = docs);
    } catch (e) {
      if (mounted) setState(() => _err = e.toString());
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDocs(String? token) async {
    // Use direct http to handle list response
    try {
      final api = ApiClient();
      // Our ApiClient.get handles list as {'data': list}, so we extract
      final res = await api.get('/api/v1/users/me/verification', token: token);
      if (res.containsKey('data') && res['data'] is List) {
        return List<Map<String, dynamic>>.from(res['data'] as List);
      }
      return [];
    } catch (_) {
      // Fallback: try raw
      return [];
    }
  }

  Future<void> _upload() async {
    setState(() { _loading = true; _err = null; _success = null; });
    try {
      final token = await AuthStorage().getAccess();
      final api = ApiClient();
      final res = await api.post('/api/v1/users/me/verification/request-upload', {
        'doc_type': _docType,
        'file_name': _fileCtrl.text.trim(),
      }, token: token);
      setState(() => _success = 'Uploaded ${res['document']['id']}');
      await _load();
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.verificationTitle)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<String>(
          value: _docType,
          decoration: InputDecoration(labelText: l10n.verificationDocType),
          items: const ['id', 'diploma', 'trade_credential']
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) => setState(() => _docType = v ?? 'id'),
        ),
        TextField(controller: _fileCtrl, decoration: InputDecoration(labelText: l10n.verificationFileName)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _loading ? null : _upload, child: _loading ? const CircularProgressIndicator() : Text(l10n.verificationUpload)),
        if (_err != null) Text(_err!, style: const TextStyle(color: Colors.red)),
        if (_success != null) Text(_success!, style: const TextStyle(color: Colors.green)),
        const Divider(height: 32),
        Text(l10n.verificationStatus, style: Theme.of(context).textTheme.titleMedium),
        ..._docs.map((d) => ListTile(
              title: Text('${d['doc_type']} - ${d['status']}'),
              subtitle: Text(d['file_url'] ?? ''),
              trailing: d['status'] == 'approved' ? const Icon(Icons.verified, color: Colors.green) : null,
            )),
      ]),
    );
  }
}
