import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../../l10n/app_localizations.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 5;
  final _commentCtrl = TextEditingController();
  bool _loading = false;
  String? _err;
  String? _success;

  Future<void> _submit() async {
    setState(() { _loading = true; _err = null; _success = null; });
    try {
      final token = await AuthStorage().getAccess();
      final api = ApiClient();
      await api.post('/api/v1/reviews/', {
        'booking_id': widget.bookingId,
        'rating': _rating,
        'comment': _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
      }, token: token);
      if (!mounted) return;
      setState(() => _success = AppLocalizations.of(context)!.reviewSuccess);
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
      appBar: AppBar(title: Text(l10n.reviewTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              value: _rating,
              decoration: InputDecoration(labelText: l10n.reviewRating),
              items: [1, 2, 3, 4, 5].map((r) => DropdownMenuItem(value: r, child: Text('$r'))).toList(),
              onChanged: (v) => setState(() => _rating = v ?? 5),
            ),
            TextField(controller: _commentCtrl, decoration: InputDecoration(labelText: l10n.reviewComment), maxLines: 3),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loading ? null : _submit, child: _loading ? const CircularProgressIndicator() : Text(l10n.reviewSubmit)),
            if (_err != null) Text(_err!, style: const TextStyle(color: Colors.red)),
            if (_success != null) Text(_success!, style: const TextStyle(color: Colors.green)),
          ],
        ),
      ),
    );
  }
}
