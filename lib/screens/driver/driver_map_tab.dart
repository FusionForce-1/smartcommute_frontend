// Driver map tab
import 'dart:async';

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
import '../../widgets/driver/traffic_report_card.dart';
import '../../widgets/driver/shift_card.dart';
import '../../widgets/map_follower.dart';

/// Driver map tab
class DriverMapTab extends StatefulWidget {
  /// Create driver map tab
  const DriverMapTab({super.key, required this.driver, this.locationSource});

  final DriverProvider driver;

  final LocationSource? locationSource;

  /// Create widget state
  @override
  State<DriverMapTab> createState() => _DriverMapTabState();
}

/// Driver map tab state
class _DriverMapTabState extends State<DriverMapTab> with TickerProviderStateMixin {
  final MapController _map = MapController();
  late final MapFollower _follow = MapFollower(_map, this);

  final GlobalKey _mapKey = GlobalKey();

  bool _expanded = false;

  LatLng? _myLocation;
  StreamSubscription<LatLng>? _phoneMoves;
  bool _locating = false;
  late final LocationSource _location = widget.locationSource ?? GeolocatorLocationSource();
  final DraggableScrollableController _sheet = DraggableScrollableController();

  final ValueNotifier<double> _sheetExtent = ValueNotifier(0);

  static const double _sheetOpen = 0.36;
  static const double _sheetMax = 0.7;
  static const double _sheetHandle = 30;

  /// Initialize widget state
  @override
  void initState() {
    super.initState();
    widget.driver.addListener(_followJeep);
    _locateOnOpen();
  }

  /// Clean up resources
  @override
  void dispose() {
    widget.driver.removeListener(_followJeep);
    _phoneMoves?.cancel();
    _follow.dispose();
    _sheet.dispose();
    _sheetExtent.dispose();
    super.dispose();
  }

  /// Follow jeep
  void _followJeep() {
    final jeep = widget.driver.jeepPosition;
    if (jeep != null) _follow.center(jeep);
  }

  /// On map ready
  void _onMapReady() {
    _follow.mapReady();
    final here = widget.driver.jeepPosition ?? _myLocation;
    if (here != null) _follow.center(here);
  }

  /// Locate on open
  Future<void> _locateOnOpen() async {
    try {
      _showMyLocation(await _location.currentLocation());
      _watchPhone();
    } catch (_) {
    }
  }

  /// Watch phone
  void _watchPhone() {
    if (!mounted) return;
    _phoneMoves ??= _location.positionStream(distanceFilterM: 5).listen(_showMyLocation, onError: (Object _) {});
  }

  /// Show my location
  void _showMyLocation(LatLng here) {
    if (!mounted) return;
    setState(() => _myLocation = here);
    if (widget.driver.jeepPosition == null) _follow.center(here);
  }

  /// Set expanded
  void _setExpanded(bool expanded) {
    if (expanded == _expanded) return;
    setState(() => _expanded = expanded);
    if (!expanded) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_expanded && _sheet.isAttached) {
        _sheet.animateTo(_sheetOpen, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      }
    });
  }

  /// Toggle sheet
  void _toggleSheet(double minSize) {
    if (!_sheet.isAttached) return;
    final open = _sheet.size > minSize + 0.02;
    _sheet.animateTo(open ? minSize : _sheetOpen, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
  }

  /// Report driver map
  Future<void> _report(Future<String?> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await action();
    if (message == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Centre on me
  Future<void> _centreOnMe() async {
    _follow.resume();
    final jeep = widget.driver.jeepPosition;
    if (jeep != null) {
      _follow.center(jeep);
      return;
    }
    if (_locating) return;
    _locating = true;
    final messenger = ScaffoldMessenger.of(context);
    try {
      _showMyLocation(await _location.currentLocation());
      _watchPhone();
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

  /// Location problem
  static String _locationProblem(LocationFailure reason) => switch (reason) {
        LocationFailure.servicesOff => "Turn on your phone's location to see where you are.",
        LocationFailure.denied => 'Allow location for SmartCommute to see where you are on the map.',
        LocationFailure.unavailable => "Couldn't get a location fix. Turn on Wi-Fi or move near a window.",
        LocationFailure.timeout => 'Finding your location took too long. Try again.',
      };

  /// Driver map
  Widget _driverMap({required bool expanded}) => DriverMap(
        key: _mapKey,
        driver: widget.driver,
        controller: _map,
        expanded: expanded,
        onToggleExpanded: () => _setExpanded(!_expanded),
        onLocate: _centreOnMe,
        following: _follow.following,
        onMapReady: _onMapReady,
        onMapEvent: _follow.onMapEvent,
        myLocation: _myLocation,
        showControls: !expanded,
      );

  /// Build the widget
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

  /// Build dashboard
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
          TrafficReportCard(
            reported: driver.trafficReported,
            onReport: shift == null ? null : (congested) => _report(() => driver.reportTraffic(congested)),
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

  /// Build full screen
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
                following: _follow.following,
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
