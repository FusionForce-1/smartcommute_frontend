// lib/widgets/stop_search_sheet.dart
//
// Searchable list sa stops para pilian sa commuter ang destination.

import 'package:flutter/material.dart';

import '../config/theme_config.dart';
import '../constants/app_icons.dart';
import '../models/transport_stop.dart';
import 'stop_image.dart';

/// Filter by name or landmark, case-insensitive. Blank query → tanan.
List<TransportStop> filterStops(List<TransportStop> stops, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return stops;
  return stops
      .where((stop) =>
          stop.name.toLowerCase().contains(q) ||
          (stop.landmark?.toLowerCase().contains(q) ?? false))
      .toList();
}

Future<TransportStop?> showStopSearchSheet(
  BuildContext context,
  List<TransportStop> stops,
) {
  return showModalBottomSheet<TransportStop>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => _StopSearchSheet(stops: stops),
  );
}

class _StopSearchSheet extends StatefulWidget {
  const _StopSearchSheet({required this.stops});

  final List<TransportStop> stops;

  @override
  State<_StopSearchSheet> createState() => _StopSearchSheetState();
}

class _StopSearchSheetState extends State<_StopSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = filterStops(widget.stops, _query);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.xs,
              ),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search stops or landmarks',
                  prefixIcon: Icon(AppIcons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          widget.stops.isEmpty
                              ? 'No stops available yet. Try "Pick on map".'
                              : 'No stops match "${_query.trim()}".',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final stop = results[index];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: StopImage(location: stop.location, size: 96),
                            ),
                          ),
                          title: Text(stop.name),
                          subtitle:
                              stop.landmark == null ? null : Text(stop.landmark!),
                          onTap: () => Navigator.of(context).pop(stop),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
