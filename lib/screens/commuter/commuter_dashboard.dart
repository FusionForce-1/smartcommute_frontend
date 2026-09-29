// lib/screens/commuter/commuter_dashboard.dart
//
// Emae D. Calonia — Commuter test dashboard scaffold.
// Bottom navigation: Map, Routes, Feedback, Profile.
// Placeholder tab bodies for navigation / layout testing.

import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';
import '../../providers/auth_provider.dart';
import '../../router/app_router.dart';  
import '../../models/transport_stop.dart';
import '../../services/stops_services.dart';
import '../../models/transport_model.dart';
import '../../services/route_services.dart';
import '../../services/websocket_service.dart';
import 'package:dio/dio.dart';


class CommuterDashboard extends StatefulWidget {
  const CommuterDashboard({super.key, this.isGuest = false});

  /// True when opened via "Continue as Guest" — profile actions stay disabled.
  final bool isGuest;

  @override
  State<CommuterDashboard> createState() => _CommuterDashboardState();
}

class _CommuterDashboardState extends State<CommuterDashboard> {
  int _currentIndex = 0;

  static const _tabs = [
    _CommuterTab(
      label: 'Map',
      icon: AppIcons.location,
      title: 'Live Map',
      description: 'Leaflet map with vehicle markers and stop pins.',
    ),
    _CommuterTab(
      label: 'Routes',
      icon: AppIcons.routeStop,
      title: 'Trip Planner',
      description: 'Origin / destination search and ranked route options.',
    ),
    _CommuterTab(
      label: 'Feedback',
      icon: AppIcons.feedback,
      title: 'Submit Feedback',
      description: 'Report delays, overcrowding, or route issues.',
    ),
    _CommuterTab(
      label: 'Profile',
      icon: AppIcons.profileAvatar,
      title: 'My Profile',
      description: 'Account details, preferences, and sign-out.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tab = _tabs[_currentIndex];

    return Scaffold(
      backgroundColor: AppColors.backgroundIceBlue,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(tab.title),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.notificationBell),
            tooltip: 'Announcements',
            onPressed: () {
              // TODO [Velez]: Wire with API/State Provider here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Announcements (preview)')),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(_tabs.length, (index) {
          return _CommuterTabPlaceholder(
            tab: _tabs[index],
            isGuest: widget.isGuest && index == 3,
          );
        }),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(icon: Icon(t.icon), label: t.label),
        ],
      ),
    );
  }
}

class _CommuterTab {
  const _CommuterTab({
    required this.label,
    required this.icon,
    required this.title,
    required this.description,
  });

  final String label;
  final IconData icon;
  final String title;
  final String description;
}

class _CommuterTabPlaceholder extends StatefulWidget {
  const _CommuterTabPlaceholder({
    required this.tab,
    required this.isGuest,
  });

  final _CommuterTab tab;
  final bool isGuest;

  @override
  State<_CommuterTabPlaceholder> createState() => 
  _CommuterTabPlaceholderState();
}

class _CommuterTabPlaceholderState 
    extends State<_CommuterTabPlaceholder> {

    final MapController _mapController = MapController();
    LatLng? _currentLocation;
      LatLng? _vehicleLocation;
      String? _vehicleId;
        final List<TransportStop> _stops = [];
        final List<TransportRoute> _routes = [];

        final Dio _dio = Dio(
          BaseOptions(
            baseUrl: 'http://localhost:8000',
          ),
        );

        late final StopsService _stopsService;
        late final RoutesService _routesService;
        late final WebSocketService _webSocketService;

        @override
          void initState() {
            super.initState();
                  _stopsService = StopsService(_dio);
                  _routesService = RoutesService(_dio);
                  // Connection ni siya sa WebSocketService para sa Live Updates sa mga Jeepney Vehicles 
                  _webSocketService = WebSocketService();
                  _webSocketService.connect();
                  _webSocketService.listenForMessages((message) {
                    print('INCOMING JSON: $message');

                    final data = jsonDecode(message as String);

                    final vehicleId = data['vehicle_id'] as String;
                    final status = data['status'] as String?;

                    if (status == 'signal_lost') {
                      setState(() {
                        _vehicleId = vehicleId;
                      });

                      return;
                    }

                    final lat = (data['lat'] as num).toDouble();
                    final lng = (data['lng'] as num).toDouble();

                    setState(() {
                      _vehicleId = vehicleId;
                      _vehicleLocation = LatLng(lat, lng);
                    });
                  });
                      _loadStops();
                      _loadRoutes();
                  }
          @override
            void dispose() {
              _webSocketService.disconnect();
              super.dispose();
}
          Future<void> _loadRoutes() async {
                try {
                  final routes = await _routesService.getRoutes();

                  setState(() {
                    _routes
                      ..clear()
                      ..addAll(routes);
                  });

                  debugPrint(
                    'Loaded ${routes.length} route(s): '
                    '${routes.map((route) => route.code).join(', ')}',
                  );
                } catch (e) {
                  debugPrint('Failed to load routes: $e');
                }
              }
      // Method ni siya to request sa Stop and and i Store niya sa _StopsList
    Future<void> _loadStops() async {
        try {
          final stops = await _stopsService.getStops();

          setState(() {
            _stops
              ..clear()
              ..addAll(stops);
          });
        } catch (e) {
          debugPrint('Failed to load stops: $e');
        }
      }

    Future<void> _getCurrentLocation(BuildContext context) async {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!context.mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission was not granted.',
              ),
            ),
          );
          return;
        }

        try {
          final position = await Geolocator.getCurrentPosition();
              
              final location = LatLng(
                position.latitude,
                position.longitude,
              );

              setState(() {
                _currentLocation = location;
              });
            _mapController.move(
              LatLng(
                position.latitude,
                position.longitude,
                ),
              15,
            );

          if (!context.mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Location:'
                '${position.latitude.toStringAsFixed(5)}, '
                '${position.longitude.toStringAsFixed(5)}',
              ),
            ),
          );
      } catch (e) {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to get your current location.'
              ),
          ),
        );
      }
    }
 
 
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.tab.label == 'Map')
                Container(
                height: 400,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: AppShadows.card,
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.25),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: LatLng(10.3157, 123.8854),
                    initialZoom: 13,
                  ),
                    children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.smartcommute.app',
                        ),

                        PolylineLayer(
                          polylines: _routes
                              .map(
                                (route) => Polyline(
                                  points: route.geometry,
                                  strokeWidth: 5,
                                  color: const Color.fromARGB(255, 33, 117, 243).withOpacity(0.7),
                                ),
                              )
                              .toList(),
                        ),

                        if (_currentLocation != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _currentLocation!,
                                width: 75,
                                height: 75,
                                child: Image.asset(
                                  'assets/icons/current_location_marker.png',
                                  width: 75,
                                  height: 75,
                                ),
                              ),
                            ],
                          ),
                        if (_vehicleLocation != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _vehicleLocation!,
                                  width: 50,
                                  height: 50,
                                  child: const Icon(
                                    Icons.directions_car,
                                    size: 45,
                                    color: Color.fromARGB(255, 233, 4, 4),
                                  ),
                                ),
                              ],
                            ),
                          
                        if (_stops.isNotEmpty) // Markers ni siya to test if Jeepney Stops is avaible
                            MarkerLayer(
                              markers: _stops.map((stop) {
                                return Marker(
                                  point: stop.location,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_on,
                                    size: 36,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],

                ),
              )
            else
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: AppShadows.card,
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.25),
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.tab.icon,
                        size: 48,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${widget.tab.label} view placeholder',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Text(
                          widget.tab.description,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: AppSpacing.sm),
          if (widget.tab.label == 'Map') ...[
            _PreviewActionTile(
              icon: AppIcons.myLocation,
              label: 'Center on my location',
              onTap: () => _getCurrentLocation(context),
            ),
            _PreviewActionTile(
              icon: AppIcons.vehicle,
              label: 'Refresh vehicle markers',
              onTap: () {
                // TODO [Velez]: Wire with API/State Provider here
              },
            ),
          ],
          if (widget.tab.label == 'Routes') ...[
            _PreviewActionTile(
              icon: AppIcons.search,
              label: 'Plan a trip',
              onTap: () {
                // TODO [Velez]: Wire with API/State Provider here
              },
            ),
            _PreviewActionTile(
              icon: AppIcons.fare,
              label: 'View fare estimate',
              onTap: () {
                // TODO [Velez]: Wire with API/State Provider here
              },
            ),
          ],
          if (widget.tab.label == 'Feedback') ...[
            _PreviewActionTile(
              icon: AppIcons.feedback,
              label: 'Open feedback form',
              onTap: () {
                // TODO [Velez]: Wire with API/State Provider here
              },
            ),
          ],
          if (widget.tab.label == 'Profile') ...[
            if (widget.isGuest)
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.errorBackground,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: const Text(
                  'Guest mode — sign in to access profile and saved trips.',
                  style: TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
            _PreviewActionTile(
              icon: AppIcons.settings,
              label: 'Account settings',
              enabled: !widget.isGuest,
              onTap: () {
                // TODO [Velez]: Wire with API/State Provider here
              },
            ),
            _PreviewActionTile(
              icon: AppIcons.logout,
              label: 'Sign out',
              onTap: () async {
                  await context.read<AuthProvider>().logout();

                     if (!context.mounted) return;

              Navigator.of(context).pushAndRemoveUntil(
                   MaterialPageRoute(
                    builder: (_) => const LoginScreenHost(),
                    ),
      (route) => false,
    );
  },
),
          ],
        ],
      ),
    );
  }
}



  



class _PreviewActionTile extends StatelessWidget {
  const _PreviewActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        enabled: enabled,
        leading: Icon(icon, color: AppColors.secondary),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
