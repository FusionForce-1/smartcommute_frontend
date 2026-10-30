// lib/screens/driver/driver_map_tab.dart
//
// The driver's Map tab. As a dashboard: the map card, the shift (started
// and ended by the operator), Route Status and the crowd estimate. Full
// screen (expand button on the map): the map fills the tab, its buttons on
// the right, and "My Route" (GPS, next stop, ETA, distance) in a sheet that
// drags up, or down to just its handle. The same map moves between the two
// layouts, keeping its camera. Back leaves full screen.
//
// "Centre on my location" is always there: it goes to the jeep when its
// position is known, else asks the phone where the driver is (off shift).

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/theme_config.dart';
import '../../providers/driver_provider.dart';
import '../../services/location_source.dart';
import '../../widgets/commuter/live_map.dart' show MapControls;
import '../../widgets/driver/crowd_estimate_card.dart';
import '../../widgets/driver/driver_map.dart';
import '../../widgets/driver/my_route_info.dart';
import '../../widgets/driver/route_status_card.dart';
import '../../widgets/driver/shift_card.dart';

class DriverMapTab extends StatefulWidget {
  const DriverMapTab({super.key, required this.driver, this.locationSource});

  final DriverProvider driver;

  /// The phone's location for "Centre on my location"; tests pass a fake.
  final LocationSource? locationSource;

  @override
  State<DriverMapTab> createState() => _DriverMapTabState();
}

class _DriverMapTabState extends State<DriverMapTab> {
  final MapController _map = MapController();

  /// Keeps the one map alive as it moves between the two layouts.
  final GlobalKey _mapKey = GlobalKey();

  bool _expanded = false;

  /// Where the phone found the driver (shown while the jeep's isn't known).
  LatLng? _myLocation;
  bool _locating = false;
  late final LocationSource _location = widget.locationSource ?? GeolocatorLocationSource();
  final DraggableScrollableController _sheet = DraggableScrollableController();

  /// How much of the full-screen height the sheet covers; the map buttons
  /// ride just above it.
  final ValueNotifier<double> _sheetExtent = ValueNotifier(0);

  static const double _sheetOpen = 0.36;
  static const double _sheetMax = 0.7;
  static const double _sheetHandle = 30;

  @override
  void dispose() {
    _sheet.dispose();
    _sheetExtent.dispose();
    super.dispose();
  }

  void _setExpanded(bool expanded) {
    if (expanded == _expanded) return;
    setState(() => _expanded = expanded);
    if (!expanded) return;
    // The sheet starts at its handle and slides up into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_expanded && _sheet.isAttached) {
        _sheet.animateTo(_sheetOpen, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      }
    });
  }

  void _toggleSheet(double minSize) {
    if (!_sheet.isAttached) return;
    final open = _sheet.size > minSize + 0.02;
    _sheet.animateTo(open ? minSize : _sheetOpen, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
  }

  /// Runs a provider action and shows the message it returns, if any.
  Future<void> _report(Future<String?> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await action();
    if (message == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// The jeep when we know where it is, else the phone's own location.
  Future<void> _centreOnMe() async {
    final jeep = widget.driver.jeepPosition;
    if (jeep != null) {
      _map.move(jeep, 16);
      return;
    }
    if (_locating) return;
    _locating = true;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final here = await _location.currentLocation();
      if (!mounted) return;
      setState(() => _myLocation = here);
      _map.move(here, 16);
    } on LocationException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_locationProblem(e.reason))));
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("Couldn't find your location. Try again.")));
    } finally {
      _locating = false;
    }
  }

  /// The planner's location messages talk about trips; these are for drivers.
  static String _locationProblem(LocationFailure reason) => switch (reason) {
        LocationFailure.servicesOff => "Turn on your phone's location to see where you are.",
        LocationFailure.denied => 'Allow location for SmartCommute to see where you are on the map.',
        LocationFailure.unavailable => "Couldn't get a location fix. Turn on Wi-Fi or move near a window.",
        LocationFailure.timeout => 'Finding your location took too long. Try again.',
      };

  Widget _driverMap({required bool expanded}) => DriverMap(
        key: _mapKey,
        driver: widget.driver,
        controller: _map,
        expanded: expanded,
        onToggleExpanded: () => _setExpanded(!_expanded),
        onLocate: _centreOnMe,
        myLocation: _myLocation,
        // Full screen: the buttons sit above the sheet, placed below.
        showControls: !expanded,
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_expanded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setExpanded(false);
      },
      child: _expanded ? _buildFullScreen() : _buildDashboard(),
    );
  }

  Widget _buildDashboard() {
    final driver = widget.driver;
    final shift = driver.shift;
    const gap = SizedBox(height: AppSpacing.sm);

    return RefreshIndicator(
      onRefresh: driver.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
        children: [
          const Text(
            'Driver Dashboard',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          ),
          gap,
          SizedBox(height: 320, child: _driverMap(expanded: false)),
          gap,
          ShiftCard(
            shift: shift,
            vehicle: driver.vehicle,
            jeepGps: driver.jeepGps,
            gpsError: driver.gpsError,
            onRetryGps: driver.retryPhoneGps,
            onPassengerChange: (change) => _report(() => driver.changePassengers(change)),
          ),
          gap,
          RouteStatusCard(
            status: driver.routeStatus,
            onChanged: shift == null ? null : (status) => _report(() => driver.setRouteStatus(status)),
          ),
          gap,
          CrowdEstimateCard(
            percent: driver.crowdPercent,
            onChanged: shift == null ? null : driver.previewCrowd,
            onChangeEnd: shift == null ? null : (percent) => _report(() => driver.commitCrowd(percent)),
          ),
        ],
      ),
    );
  }

  Widget _buildFullScreen() {
    final driver = widget.driver;
    return LayoutBuilder(
      builder: (context, box) {
        final height = box.maxHeight;
        final minSize = (_sheetHandle / height).clamp(0.02, 0.2);
        return Stack(
          children: [
            Positioned.fill(child: _driverMap(expanded: true)),
            ValueListenableBuilder<double>(
              valueListenable: _sheetExtent,
              builder: (context, extent, controls) {
                final bottom = extent.clamp(minSize, 1.0) * height + AppSpacing.xs;
                // Fade the buttons out once the sheet climbs into their way.
                final hidden = bottom > height * 0.6;
                return Positioned(
                  right: AppSpacing.sm,
                  bottom: bottom,
                  child: IgnorePointer(
                    ignoring: hidden,
                    child: AnimatedOpacity(
                      opacity: hidden ? 0 : 1,
                      duration: const Duration(milliseconds: 150),
                      child: controls,
                    ),
                  ),
                );
              },
              child: MapControls(
                controller: _map,
                expanded: true,
                onToggleExpanded: () => _setExpanded(false),
                onLocate: _centreOnMe,
              ),
            ),
            NotificationListener<DraggableScrollableNotification>(
              onNotification: (n) {
                _sheetExtent.value = n.extent;
                return false;
              },
              child: DraggableScrollableSheet(
                controller: _sheet,
                initialChildSize: minSize,
                minChildSize: minSize,
                maxChildSize: _sheetMax,
                snap: true,
                snapSizes: const [_sheetOpen],
                builder: (context, scroll) => Material(
                  key: const Key('myRouteSheet'),
                  color: Colors.white,
                  elevation: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.sm)),
                  clipBehavior: Clip.antiAlias,
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                    children: [
                      // Drag here, or tap to open / minimize.
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _toggleSheet(minSize),
                        child: SizedBox(
                          height: _sheetHandle,
                          child: Center(
                            child: Container(
                              key: const Key('myRouteSheetHandle'),
                              width: 64,
                              height: 5,
                              decoration: BoxDecoration(
                                color: AppColors.divider,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      MyRouteInfo(driver: driver),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
