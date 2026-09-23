import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../bookings/booking_request_screen.dart';

class CraftsmanProfileScreen extends StatelessWidget {
  const CraftsmanProfileScreen({super.key, required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.craftsmanProfileTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(data['name'] ?? 'Craftsman', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Trades: ${data['trades']}'),
            Text('Bio: ${data['bio'] ?? ''}'),
            Text('Rate: ${data['hourly_rate'] ?? ''} DZD / hour'),
            Text('Rating: ${data['rating_avg']}'),
            if (data['distance_km'] != null) Text('Distance: ${data['distance_km']} km'),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingRequestScreen(craftsmanId: data['user_id'] as String, craftsmanName: data['name'] ?? 'Craftsman'))),
              child: const Text('Request booking'),
            ),
          ],
        ),
      ),
    );
  }
}
