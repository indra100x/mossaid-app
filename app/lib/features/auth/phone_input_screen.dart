import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../l10n/app_localizations.dart';
import 'otp_screen.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key, this.api});
  final ApiClient? api;

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final _phoneCtrl = TextEditingController(text: '+213');
  bool _loading = false;
  String? _err;

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context)!;
    final phone = _phoneCtrl.text.trim();
    if (!phone.startsWith('+') || phone.length < 8) {
      setState(() => _err = l10n.validationFailed);
      return;
    }
    setState(() { _loading = true; _err = null; });
    try {
      final api = widget.api ?? ApiClient();
      await api.post('/api/v1/auth/request-otp', {'phone': phone});
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => OtpScreen(phone: phone, api: api)));
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
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.onboardingTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneCtrl,
              decoration: InputDecoration(labelText: l10n.phoneLabel, hintText: l10n.phoneHint),
              keyboardType: TextInputType.phone,
            ),
            if (_err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_err!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loading ? null : _send, child: _loading ? const CircularProgressIndicator() : Text(l10n.sendOtp)),
          ],
        ),
      ),
    );
  }
}
