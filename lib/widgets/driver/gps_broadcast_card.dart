// lib/widgets/driver/gps_broadcast_card.dart
//
// Location-sharing switch. While sharing, it shows how the broadcast is
// going and a button to see it on the map.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../services/websocket_service.dart';
import 'driver_card.dart';

class GpsBroadcastCard extends StatelessWidget {
  const GpsBroadcastCard({
    super.key,
    required this.session,
    required this.onChanged,
    required this.onViewLive,
  });

  final GpsIngestionSession session;
  final ValueChanged<bool> onChanged;
  final VoidCallback onViewLive;

  String get _subtitle => switch (session.state) {
        GpsSessionState.idle => 'Share your location with commuters',
        GpsSessionState.connecting => 'Connecting to the GPS server…',
        GpsSessionState.live => session.framesSent == 0
            ? 'Waiting for your first GPS fix…'
            : 'Sharing your location · ${session.framesSent} updates sent',
        GpsSessionState.reconnecting => 'Connection lost — reconnecting…',
        GpsSessionState.paused => 'Sending paused',
        GpsSessionState.error => session.error ?? 'GPS stopped.',
      };

  @override
  Widget build(BuildContext context) {
    final on = session.isActive;
    final isError = session.state == GpsSessionState.error;

    return DriverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('GPS Broadcast', style: DriverCard.titleStyle),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle,
                      style: TextStyle(
                        fontSize: 15,
                        color: isError ? AppColors.error : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: on,
                onChanged: onChanged,
                activeThumbColor: AppColors.brandTeal,
                activeTrackColor: Colors.white,
                inactiveThumbColor: AppColors.navInactive,
                inactiveTrackColor: Colors.white,
                trackOutlineColor: WidgetStatePropertyAll(on ? AppColors.brandTeal : AppColors.navInactive),
              ),
            ],
          ),
          if (on) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, thickness: 1.4, color: AppColors.divider),
            ),
            OutlinedButton.icon(
              onPressed: onViewLive,
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('View Live Broadcast'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                minimumSize: const Size.fromHeight(46),
                side: const BorderSide(color: AppColors.divider, width: 1.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
