import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../../l10n/app_localizations.dart';

class BookingRequestScreen extends StatefulWidget {
  const BookingRequestScreen({super.key, required this.craftsmanId, required this.craftsmanName});
  final String craftsmanId;
  final String craftsmanName;
  @override
  State<BookingRequestScreen> createState() => _BookingRequestScreenState();
}

class _BookingRequestScreenState extends State<BookingRequestScreen> {
  final _tradeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 2));
  bool _loading = false;
  String? _err;
  String? _success;

  Future<void> _submit() async {
    setState(() { _loading = true; _err = null; _success = null; });
    try {
      final token = await AuthStorage().getAccess();
      final api = ApiClient();
      await api.post('/api/v1/bookings/', {
        'craftsman_id': widget.craftsmanId,
        'trade': _tradeCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'address': _addrCtrl.text.trim(),
        'scheduled_at': _date.toUtc().toIso8601String(),
      }, token: token);
      if (!mounted) return;
      setState(() => _success = AppLocalizations.of(context)!.bookingSuccess);
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
      appBar: AppBar(title: Text(l10n.bookingRequestTitle)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Craftsman: ${widget.craftsmanName}'),
        TextField(controller: _tradeCtrl, decoration: InputDecoration(labelText: l10n.bookingTradeLabel)),
        TextField(controller: _descCtrl, decoration: InputDecoration(labelText: l10n.bookingDescriptionLabel), maxLines: 3),
        TextField(controller: _addrCtrl, decoration: InputDecoration(labelText: l10n.bookingAddressLabel)),
        ListTile(title: Text('${l10n.bookingDateLabel}: ${_date.toLocal().toString().split(' ').first}'), trailing: IconButton(icon: const Icon(Icons.calendar_today), onPressed: () async { final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)), initialDate: _date); if (d != null) setState(() => _date = d); })),
        if (_err != null) Text(_err!, style: const TextStyle(color: Colors.red)),
        if (_success != null) Text(_success!, style: const TextStyle(color: Colors.green)),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _loading ? null : _submit, child: _loading ? const CircularProgressIndicator() : Text(l10n.bookingSubmit)),
      ]),
    );
  }
}
