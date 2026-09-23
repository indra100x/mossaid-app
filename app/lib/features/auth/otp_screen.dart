import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../../core/fcm_service.dart';
import '../../l10n/app_localizations.dart';
import '../profile/profile_setup_screen.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phone, this.api, this.storage});
  final String phone;
  final ApiClient? api;
  final AuthStorage? storage;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpCtrl = TextEditingController();
  bool _loading = false;
  String? _err;

  Future<void> _verify() async {
    setState(() { _loading = true; _err = null; });
    try {
      final api = widget.api ?? ApiClient();
      final res = await api.post('/api/v1/auth/verify-otp', {'phone': widget.phone, 'otp': _otpCtrl.text.trim()});
      final access = res['access_token'] as String;
      final refresh = res['refresh_token'] as String;
      await (widget.storage ?? AuthStorage()).saveTokens(access: access, refresh: refresh);
      // FCM: Android 13+ permission + getToken, send to backend (multiple tokens per user)
      try {
        final fcm = FcmService(api: api, storage: widget.storage ?? AuthStorage());
        await fcm.registerTokenAfterLogin();
        await fcm.setupForegroundHandlers();
      } catch (_) {}
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfileSetupScreen()));
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
      appBar: AppBar(title: Text(l10n.otpLabel)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _otpCtrl, decoration: InputDecoration(labelText: l10n.otpLabel, hintText: l10n.otpHint), keyboardType: TextInputType.number, maxLength: 6),
            if (_err != null) Text(_err!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loading ? null : _verify, child: _loading ? const CircularProgressIndicator() : Text(l10n.verifyOtp)),
          ],
        ),
      ),
    );
  }
}
