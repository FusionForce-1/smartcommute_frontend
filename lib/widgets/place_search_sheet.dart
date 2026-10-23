// lib/widgets/place_search_sheet.dart
//
// "Where from / where to?" sheet for Plan Your Route. Typing shows, at once,
// the saved stops and every Metro Cebu landmark that matches (see
// services/place_search.dart), nearest to [near] first. For anything not
// listed, "Search online" asks OpenStreetMap (Nominatim) — only on tap, as
// its usage policy asks (no search-as-you-type).

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../config/theme_config.dart';
import '../constants/app_icons.dart';
import '../models/transport_stop.dart';
import '../services/place_search.dart';
import 'stop_image.dart';

/// Opens the sheet; pops with the chosen place, or null.
Future<Place?> showPlaceSearchSheet(
  BuildContext context, {
  required List<TransportStop> stops,
  required String title,
  LatLng? near,
}) {
  return showModalBottomSheet<Place>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => _PlaceSearchSheet(stops: stops, title: title, near: near),
  );
}

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

class _PlaceSearchSheet extends StatefulWidget {
  const _PlaceSearchSheet({required this.stops, required this.title, this.near});

  final List<TransportStop> stops;
  final String title;
  final LatLng? near;

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  static final Dio _http = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    // Nominatim asks apps to identify themselves (ignored by browsers).
    headers: {'User-Agent': 'SmartCommute/1.0 (commuter app)', 'Accept-Language': 'en'},
  ));

  late final PlaceIndex _stops = PlaceIndex([
    for (final s in widget.stops) Place(name: s.name, location: s.location, kind: 'Your stop'),
  ]);
  PlaceIndex _landmarks = PlaceIndex(const []);
  bool _landmarksReady = false;

  String _query = '';
  List<PlaceMatch> _online = const [];
  String? _onlineNote;
  bool _searchingOnline = false;

  @override
  void initState() {
    super.initState();
    // Usually already loaded (the Route tab opens it once): use it right away.
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

  TransportStop? _stopNamed(Place p) {
    for (final s in widget.stops) {
      if (s.name == p.name && s.location == p.location) return s;
    }
    return null;
  }

  List<PlaceMatch> _localMatches() {
    final mine = _stops.search(_query, near: widget.near, limit: 4);
    final taken = {for (final m in mine) foldPlaceText(m.place.name)};
    final others = _landmarks
        .search(_query, near: widget.near, limit: 12)
        .where((m) => !taken.contains(foldPlaceText(m.place.name)));
    return [...mine, ...others].take(12).toList();
  }

  Future<void> _searchOnline() async {
    final q = _query.trim();
    if (q.length < 3 || _searchingOnline) return;
    setState(() { _searchingOnline = true; _onlineNote = null; });
    try {
      final center = widget.near;
      final res = await _http.get<List<dynamic>>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': q, 'format': 'jsonv2', 'countrycodes': 'ph', 'limit': 6,
          if (center != null) 'viewbox': '${center.longitude - 0.3},${center.latitude + 0.3},'
              '${center.longitude + 0.3},${center.latitude - 0.3}',
          'bounded': 0,
        },
      );
      const distance = Distance();
      final results = [
        for (final r in res.data ?? const [])
          if (r is Map && r['lat'] != null && r['lon'] != null)
            () {
              final at = LatLng(double.parse('${r['lat']}'), double.parse('${r['lon']}'));
              final name = (r['name'] as String?)?.trim().isNotEmpty == true
                  ? r['name'] as String
                  : '${r['display_name']}'.split(',').take(2).join(',').trim();
              return (
                place: Place(name: name, location: at, kind: 'Online result'),
                metres: center == null ? 0.0 : distance.as(LengthUnit.Meter, center, at),
              );
            }(),
      ];
      if (!mounted) return;
      setState(() {
        _online = results;
        _onlineNote = results.isEmpty ? 'Nothing found online for "$q". Try a nearby landmark.' : null;
      });
    } catch (_) {
      if (mounted) setState(() => _onlineNote = 'Online search is unavailable right now. Check your connection.');
    } finally {
      if (mounted) setState(() => _searchingOnline = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final typed = _query.trim();
    final local = _localMatches();
    final online = _online.where((o) => !local.any((l) => foldPlaceText(l.place.name) == foldPlaceText(o.place.name)));

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
                onChanged: (value) => setState(() { _query = value; _online = const []; _onlineNote = null; }),
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
                        if (local.isEmpty && online.isEmpty && _onlineNote == null && !_searchingOnline)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Text('No place named "$typed" nearby.', style: const TextStyle(color: AppColors.textSecondary)),
                          ),
                        if (_onlineNote != null)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Text(_onlineNote!, style: const TextStyle(color: AppColors.textSecondary)),
                          ),
                        if (typed.length >= 3)
                          ListTile(
                            leading: _searchingOnline
                                ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.travel_explore),
                            title: Text(_searchingOnline ? 'Searching online…' : 'Search online for "$typed"'),
                            subtitle: const Text('If the place isn\'t listed above'),
                            onTap: _searchingOnline ? null : _searchOnline,
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
