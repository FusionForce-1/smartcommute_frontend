// lib/widgets/commuter/review_ride_sheet.dart
//
// "Rate your ride": which route and jeep (by its plate number), 1-5 stars,
// quick tags and an optional comment. The backend credits it to the jeep's
// assigned driver; the operator sees it without the commuter's name.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/ride_review.dart';
import '../../models/transport_model.dart';
import '../../models/vehicles.dart';
import '../../providers/profile_provider.dart';

/// Opens the sheet; resolves to true when a review was sent.
Future<bool?> showReviewRideSheet(
  BuildContext context, {
  required ProfileProvider profile,
  required List<TransportRoute> routes,
  required List<Vehicle> vehicles,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) =>
        _ReviewRideSheet(profile: profile, routes: routes, vehicles: vehicles),
  );
}

const String _unknownPlate = '__unknown__';

class _ReviewRideSheet extends StatefulWidget {
  const _ReviewRideSheet(
      {required this.profile, required this.routes, required this.vehicles});

  final ProfileProvider profile;
  final List<TransportRoute> routes;
  final List<Vehicle> vehicles;

  @override
  State<_ReviewRideSheet> createState() => _ReviewRideSheetState();
}

class _ReviewRideSheetState extends State<_ReviewRideSheet> {
  late String? _routeId =
      widget.routes.length == 1 ? widget.routes.first.id : null;
  String? _vehicleId;
  int _rating = 0;
  final Set<String> _tags = {};
  final _comment = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  List<Vehicle> get _jeeps => [
        for (final v in widget.vehicles)
          if (v.routeId == _routeId) v
      ];

  bool get _ready =>
      _routeId != null && _vehicleId != null && _rating > 0 && !_sending;

  static const _ratingWords = [
    '',
    'Very bad',
    'Bad',
    'Okay',
    'Good',
    'Excellent'
  ];

  Future<void> _submit() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final error = await widget.profile.submitReview(
      routeId: _routeId!,
      vehicleId: _vehicleId == _unknownPlate ? null : _vehicleId,
      rating: _rating,
      tags: _tags.toList(),
      comment: _comment.text,
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _sending = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final jeeps = _jeeps;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Rate your ride',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text(
                "Your review goes to the jeep's operator and counts for its driver. Your name isn't shown to them.",
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _routeId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Route you rode'),
                items: [
                  for (final r in widget.routes)
                    DropdownMenuItem(
                        value: r.id,
                        child: Text('${r.code} — ${r.name}',
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (id) => setState(() {
                  _routeId = id;
                  _vehicleId = null;
                }),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                key: ValueKey(_routeId), // reset when the route changes
                initialValue: _vehicleId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Jeep (plate number)',
                  helperText:
                      'The plate is painted on the front and back of the jeepney.',
                ),
                items: [
                  for (final v in jeeps)
                    DropdownMenuItem(value: v.id, child: Text(v.plateNumber)),
                  const DropdownMenuItem(
                      value: _unknownPlate,
                      child: Text("Not sure of the plate")),
                ],
                onChanged: _routeId == null
                    ? null
                    : (id) => setState(() => _vehicleId = id),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  for (var star = 1; star <= 5; star++)
                    IconButton(
                      tooltip: '$star star${star > 1 ? 's' : ''}',
                      onPressed: () => setState(() => _rating = star),
                      icon: Icon(
                          star <= _rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 36,
                          color: const Color(0xFFF5A623)),
                    ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(_ratingWords[_rating],
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in ReviewTag.all)
                    FilterChip(
                      label: Text(tag.label),
                      selected: _tags.contains(tag.key),
                      selectedColor: tag.positive
                          ? const Color(0xFFDFF3E7)
                          : const Color(0xFFFBE3E1),
                      onSelected: (on) => setState(() {
                        if (on && _tags.length >= 6) return;
                        on ? _tags.add(tag.key) : _tags.remove(tag.key);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _comment,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Comment (optional)',
                    hintText: 'What went well, or what should change?'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.error)),
                ),
              FilledButton(
                onPressed: _ready ? _submit : null,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandTeal,
                    minimumSize: const Size.fromHeight(48)),
                child: Text(_sending ? 'Sending…' : 'Submit review'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
