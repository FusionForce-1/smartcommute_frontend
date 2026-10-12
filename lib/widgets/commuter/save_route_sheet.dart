// lib/widgets/commuter/save_route_sheet.dart
//
// "+ Add" on the Profile tab: name a route ("Home → Office"), pick its
// From / To stops and the jeepney route, then save it to the profile.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/transport_model.dart';
import '../../models/transport_stop.dart';
import '../../providers/profile_provider.dart';
import '../stop_search_sheet.dart';
import 'commuter_field_box.dart';
import 'commuter_primary_button.dart';

/// [profile] is passed in because the sheet opens outside the dashboard's
/// provider scope.
Future<void> showSaveRouteSheet(
  BuildContext context, {
  required ProfileProvider profile,
  required List<TransportStop> stops,
  required List<TransportRoute> routes,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => SaveRouteSheet(profile: profile, stops: stops, routes: routes),
  );
}

class SaveRouteSheet extends StatefulWidget {
  const SaveRouteSheet({
    super.key,
    required this.profile,
    required this.stops,
    required this.routes,
  });

  final ProfileProvider profile;
  final List<TransportStop> stops;
  final List<TransportRoute> routes;

  @override
  State<SaveRouteSheet> createState() => _SaveRouteSheetState();
}

class _SaveRouteSheetState extends State<SaveRouteSheet> {
  final _label = TextEditingController();
  TransportStop? _from;
  TransportStop? _to;
  String? _routeId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  /// Routes serving both chosen stops; every route until both are chosen
  /// (or when none serves both).
  List<TransportRoute> get _routeChoices {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return widget.routes;
    final both = widget.routes
        .where((r) => from.routeIds.contains(r.id) && to.routeIds.contains(r.id))
        .toList();
    return both.isEmpty ? widget.routes : both;
  }

  bool get _canSave =>
      !_saving && _label.text.trim().isNotEmpty && _from != null && _to != null && _routeId != null;

  Future<void> _pickStop({required bool isFrom}) async {
    final stop = await showStopSearchSheet(context, widget.stops);
    if (stop == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = stop;
      } else {
        _to = stop;
      }
      final choices = _routeChoices;
      if (!choices.any((r) => r.id == _routeId)) {
        _routeId = choices.length == 1 ? choices.single.id : null;
      }
    });
  }

  Future<void> _save() async {
    final from = _from!;
    final to = _to!;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.profile.addSavedRoute(
      label: _label.text,
      routeId: _routeId!,
      originName: from.name,
      destinationName: to.name,
      origin: from.location,
      destination: to.location,
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;

    return Padding(
      // Lift the form above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Save a Route', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _label,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Home → Office'),
              onChanged: (_) => setState(() {}),
            ),
            const _Label('From'),
            CommuterFieldBox(
              hint: 'Choose a stop',
              value: _from?.name,
              onTap: () => _pickStop(isFrom: true),
            ),
            const SizedBox(height: AppSpacing.sm),
            const _Label('To'),
            CommuterFieldBox(
              hint: 'Choose a stop',
              value: _to?.name,
              onTap: () => _pickStop(isFrom: false),
            ),
            const SizedBox(height: AppSpacing.sm),
            const _Label('Route'),
            DropdownButtonFormField<String>(
              key: ValueKey(_routeId), // reset when the choices narrow
              initialValue: _routeId,
              hint: const Text('Choose a route'),
              isExpanded: true,
              items: [
                for (final route in _routeChoices)
                  DropdownMenuItem(value: route.id, child: Text('${route.code} – ${route.name}')),
              ],
              onChanged: (id) => setState(() => _routeId = id),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(error, style: const TextStyle(color: AppColors.error)),
              ),
            const SizedBox(height: AppSpacing.md),
            CommuterPrimaryButton(label: 'Save Route', onPressed: _canSave ? _save : null),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
    );
  }
}
