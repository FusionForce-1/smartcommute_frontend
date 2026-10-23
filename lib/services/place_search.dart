// lib/services/place_search.dart
//
// Searchable places for the commuter's From / To boxes: the saved stops plus
// ~6,000 Metro Cebu landmarks (malls, terminals, schools, churches,
// barangays...) from the same OpenStreetMap data the map shows. The list is
// bundled as assets/data/cebu_landmarks.json, built by
// Smart-Commute-Backend/tools/build_landmarks.py (same file as the operator
// portal's), so matches appear instantly while typing, offline too.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

/// A place the commuter can travel from or to.
class Place {
  const Place({required this.name, required this.location, required this.kind});

  final String name;
  final LatLng location;

  /// What it is, shown under the name: "Mall / supermarket", "Your stop"...
  final String kind;
}

/// A search hit: the place and how far it is from where the search centred.
typedef PlaceMatch = ({Place place, double metres});

const Map<String, String> _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ñ': 'n', 'ç': 'c',
};

/// Lowercase, no accents or punctuation: "Santo Niño!" -> "santo nino".
String foldPlaceText(String text) {
  final lower = text.toLowerCase();
  final buf = StringBuffer();
  for (final ch in lower.split('')) {
    buf.write(_accents[ch] ?? ch);
  }
  return buf.toString().replaceAll(RegExp('[^a-z0-9]+'), ' ').trim();
}

class _Entry {
  _Entry(this.place) : folded = foldPlaceText(place.name) {
    words = folded.split(' ');
  }

  final Place place;
  final String folded;
  late final List<String> words;
}

/// Places with instant "starts with the words you typed" search.
class PlaceIndex {
  PlaceIndex(Iterable<Place> places) : _entries = [for (final p in places) _Entry(p)];

  final List<_Entry> _entries;
  static const Distance _distance = Distance();

  bool get isEmpty => _entries.isEmpty;

  static Future<PlaceIndex>? _landmarks;
  static PlaceIndex? _loaded;

  /// The bundled Metro Cebu landmarks, loaded once. Empty if unavailable.
  static Future<PlaceIndex> landmarks() =>
      _landmarks ??= _loadLandmarks().then((index) => _loaded = index);

  /// The landmarks if they have finished loading (no waiting), else null.
  static PlaceIndex? get loadedLandmarks => _loaded;

  static Future<PlaceIndex> _loadLandmarks() async {
    try {
      final raw = await rootBundle.loadString('assets/data/cebu_landmarks.json');
      return PlaceIndex.fromLandmarkJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return PlaceIndex(const []);
    }
  }

  /// {"kinds": [...], "places": [[name, lat, lng, kindIndex], ...]}
  factory PlaceIndex.fromLandmarkJson(Map<String, dynamic> json) {
    final kinds = (json['kinds'] as List).cast<String>();
    return PlaceIndex([
      for (final row in json['places'] as List)
        Place(
          name: row[0] as String,
          location: LatLng((row[1] as num).toDouble(), (row[2] as num).toDouble()),
          kind: (row[3] as int) < kinds.length ? kinds[row[3] as int] : 'Place',
        ),
    ]);
  }

  /// Best matches for [query], nearest [near] first within each tier:
  /// whole name starts with it, then every typed word starts a word
  /// ("sm ceb" -> SM City Cebu), then (3+ letters) anywhere in the name.
  /// One hit per name (e.g. a stop on each side of the road).
  List<PlaceMatch> search(String query, {LatLng? near, int limit = 8}) {
    final q = foldPlaceText(query);
    if (q.length < 2) return const [];
    final tokens = q.split(' ');
    final scored = <({_Entry e, int rank, double metres})>[];
    for (final e in _entries) {
      final int rank;
      if (e.folded.startsWith(q)) {
        rank = 0;
      } else if (tokens.every((t) => e.words.any((w) => w.startsWith(t)))) {
        rank = 1;
      } else if (q.length >= 3 && e.folded.contains(q)) {
        rank = 2;
      } else {
        continue;
      }
      final metres = near == null ? 0.0 : _distance.as(LengthUnit.Meter, near, e.place.location);
      scored.add((e: e, rank: rank, metres: metres));
    }
    scored.sort((a, b) => a.rank != b.rank ? a.rank - b.rank : a.metres.compareTo(b.metres));
    final seen = <String>{};
    final out = <PlaceMatch>[];
    for (final s in scored) {
      if (!seen.add(s.e.folded)) continue;
      out.add((place: s.e.place, metres: s.metres));
      if (out.length >= limit) break;
    }
    return out;
  }

  /// The named place closest to [point], if one is within [maxMetres].
  PlaceMatch? nearest(LatLng point, {double maxMetres = 150}) {
    PlaceMatch? best;
    for (final e in _entries) {
      final m = _distance.as(LengthUnit.Meter, point, e.place.location);
      if (m <= maxMetres && (best == null || m < best.metres)) best = (place: e.place, metres: m);
    }
    return best;
  }
}

/// "350 m away" / "2.4 km away".
String formatPlaceDistance(double metres) =>
    metres < 1000 ? '${metres.round()} m away' : '${(metres / 1000).toStringAsFixed(1)} km away';
