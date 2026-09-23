import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../../l10n/app_localizations.dart';
import '../discovery/search_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameCtrl = TextEditingController();
  String _role = 'client';
  String _lang = 'fr';
  final _tradesCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  bool _loading = false;
  String? _err;

  Future<void> _save() async {
    setState(() { _loading = true; _err = null; });
    try {
      final token = await AuthStorage().getAccess();
      final api = ApiClient();
      final Map<String, dynamic> body = {
        'name': _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        'role': _role,
        'language_pref': _lang,
      };
      if (_role == 'craftsman') {
        final trades = _tradesCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        body['craftsman_profile'] = {
          if (trades.isNotEmpty) 'trades': trades,
          if (_bioCtrl.text.isNotEmpty) 'bio': _bioCtrl.text,
          'service_radius_km': 20,
          'latitude': 36.7525,
          'longitude': 3.0420,
          'hourly_rate': 1500,
        };
      }
      // remove nulls
      body.removeWhere((k, v) => v == null);
      await api.patch('/api/v1/users/me', body, token: token);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
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
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: l10n.nameLabel)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: _role, decoration: InputDecoration(labelText: l10n.roleLabel), items: ['client','craftsman'].map((r) => DropdownMenuItem(value: r, child: Text(r == 'client' ? l10n.roleClient : l10n.roleCraftsman))).toList(), onChanged: (v) => setState(() => _role = v ?? 'client')),
        DropdownButtonFormField<String>(value: _lang, decoration: InputDecoration(labelText: l10n.languageLabel), items: const ['fr','ar'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(), onChanged: (v) => setState(() => _lang = v ?? 'fr')),
        if (_role == 'craftsman') ...[
          const SizedBox(height: 12),
          TextField(controller: _tradesCtrl, decoration: InputDecoration(labelText: l10n.craftsmanTradesLabel, hintText: 'plumber, electrician')),
          TextField(controller: _bioCtrl, decoration: InputDecoration(labelText: l10n.craftsmanBioLabel)),
        ],
        if (_err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_err!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _loading ? null : _save, child: _loading ? const CircularProgressIndicator() : Text(l10n.saveProfile)),
      ]),
    );
  }
}
