// Place search sheet
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../config/theme_config.dart';
import '../constants/app_icons.dart';
import '../models/transport_stop.dart';
import '../services/dio_interceptor.dart';
import '../services/place_search.dart';
import 'stop_image.dart';

/// Show place search sheet
Future<Place?> showPlaceSearchSheet(
  BuildContext context, {
  required List<TransportStop> stops,
  required String title,
  LatLng? near,
  ServerPlaceSearch? online,
}) {
  return showModalBottomSheet<Place>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => PlaceSearchSheet(stops: stops, title: title, near: near, online: online),
  );
}

/// Kind icon
IconData _kindIcon(String kind) {
  final k = kind.toLowerCase();
  if (k.contains('your stop') || k.contains('stop') || k.contains('terminal')) return Icons.directions_bus_outlined;
  if (k.contains('mall') || k.contains('market') || k.contains('business')) return Icons.storefront_outlined;
  if (k.contains('school')) return Icons.school_outlined;
  if (k.contains('hospital')) return Icons.local_hospital_outlined;
  if (k.contains('church')) return Icons.church_outlined;
  if (k.contains('airport')) return Icons.flight_outlined;
  if (k.contains('park')) return Icons.park_outlined;
  if (k.contains('barangay') || k.contains('area')) return Icons.holiday_village_outlined;
  if (k.contains('public office')) return Icons.account_balance_outlined;
  return Icons.place_outlined;
}

/// Place search sheet
class PlaceSearchSheet extends StatefulWidget {
  /// Create place search sheet
  const PlaceSearchSheet({super.key, required this.stops, required this.title, this.near, this.online});

  final List<TransportStop> stops;
  final String title;
  final LatLng? near;

  final ServerPlaceSearch? online;

  /// Create widget state
  @override
  State<PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

/// Place search sheet state
class _PlaceSearchSheetState extends State<PlaceSearchSheet> {
  static const debounce = Duration(milliseconds: 300);

  late final ServerPlaceSearch _server = widget.online ?? ServerPlaceSearch(buildDioClient());
  Timer? _debounce;
  int _searchId = 0;

  late final PlaceIndex _stops = PlaceIndex([
    for (final s in widget.stops) Place(name: s.name, location: s.location, kind: 'Your stop'),
  ]);
  PlaceIndex _landmarks = PlaceIndex(const []);
  bool _landmarksReady = false;

  String _query = '';
  List<PlaceMatch> _online = const [];
  bool _searchingOnline = false;

  /// Clean up resources
  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Query changed
  void _onQuery(String value) {
    setState(() {
      _query = value;
      _online = const [];
    });
    _debounce?.cancel();
    if (value.trim().length >= 3) _debounce = Timer(debounce, _searchOnline);
  }

  /// Initialize widget state
  @override
  void initState() {
    super.initState();
    final ready = PlaceIndex.loadedLandmarks;
    if (ready != null) {
      _landmarks = ready;
      _landmarksReady = true;
      return;
    }
    PlaceIndex.landmarks().then((index) {
      if (mounted) setState(() { _landmarks = index; _landmarksReady = true; });
    });
  }

  /// Stop named
  TransportStop? _stopNamed(Place p) {
    for (final s in widget.stops) {
      if (s.name == p.name && s.location == p.location) return s;
    }
    return null;
  }

  /// Local matches
  List<PlaceMatch> _localMatches() {
    final mine = _stops.search(_query, near: widget.near, limit: 4);
    final taken = {for (final m in mine) foldPlaceText(m.place.name)};
    final others = _landmarks
        .search(_query, near: widget.near, limit: 12)
        .where((m) => !taken.contains(foldPlaceText(m.place.name)));
    return [...mine, ...others].take(12).toList();
  }

  /// Search online
  Future<void> _searchOnline() async {
    final q = _query.trim();
    if (q.length < 3) return;
    final id = ++_searchId;
    setState(() => _searchingOnline = true);
    try {
      final center = widget.near;
      const distance = Distance();
      final places = await _server.search(q, near: center);
      if (!mounted || id != _searchId) return;
      setState(() => _online = [
            for (final p in places)
              (place: p, metres: center == null ? 0.0 : distance.as(LengthUnit.Meter, center, p.location)),
          ]);
    } catch (_) {
      if (mounted && id == _searchId) setState(() => _online = const []);
    } finally {
      if (mounted && id == _searchId) setState(() => _searchingOnline = false);
    }
  }

  /// Place search tile
  Widget _tile(PlaceMatch m) {
    final stop = m.place.kind == 'Your stop' ? _stopNamed(m.place) : null;
    final distanceText = widget.near == null ? '' : ' · ${formatPlaceDistance(m.metres)}';
    return ListTile(
      leading: stop != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(width: 44, height: 44, child: StopImage(location: stop.location, size: 88)),
            )
          : CircleAvatar(
              backgroundColor: AppColors.backgroundIceBlue,
              foregroundColor: AppColors.primary,
              child: Icon(_kindIcon(m.place.kind), size: 22),
            ),
      title: Text(m.place.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${m.place.kind}$distanceText'),
      onTap: () => Navigator.of(context).pop(m.place),
    );
  }

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final typed = _query.trim();
    final local = _localMatches();
    final online = newOnlineMatches(local, _online);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
              child: Text(widget.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.xs),
              child: TextField(
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Stop, mall, school, church, barangay…',
                  prefixIcon: Icon(AppIcons.search),
                ),
                onChanged: _onQuery,
                onSubmitted: (_) => _searchOnline(),
              ),
            ),
            Expanded(
              child: typed.length < 2
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        _landmarksReady
                            ? 'Type a place: your stops and landmarks around Metro Cebu show up as you type.'
                            : 'Loading places…',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final m in local) _tile(m),
                        for (final m in online) _tile(m),
                        if (_searchingOnline)
                          const ListTile(
                            leading: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                            title: Text('Searching more places…'),
                          ),
                        if (local.isEmpty && online.isEmpty && !_searchingOnline)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Text('No place named "$typed" nearby.', style: const TextStyle(color: AppColors.textSecondary)),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
