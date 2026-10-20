// lib/screens/loading_screen.dart
//
// Loading screen: the logo lockup with "Cebu City Transit Information" and a
// spinner on ice blue, shown while the app starts (loading .env and finding
// which backend answers — up to a minute if the cloud server is asleep).
// web/index.html draws the same screen in HTML while the app downloads, so
// the hand-over is seamless — keep the two looking alike.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../config/theme_config.dart';
import '../widgets/auth/smart_commute_logo.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  /// Height of the logo image (which has some empty margin built in).
  static const double logoHeight = 220;

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.backgroundIceBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SmartCommuteLogo(height: logoHeight),
            SizedBox(height: 24),
            CupertinoActivityIndicator(
              key: Key('loadingSpinner'),
              radius: 44,
              color: Color(0xFF1A1A1A),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows [LoadingScreen] until [load] finishes, then [builder]'s app.
class AppLoader extends StatefulWidget {
  const AppLoader({super.key, required this.load, required this.builder});

  final Future<void> Function() load;
  final WidgetBuilder builder;

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await widget.load();
    } catch (e) {
      // Start anyway: the app shows its own "can't reach the server"
      // messages, which beats being stuck on the loading screen.
      debugPrint('Startup failed: $e');
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.builder(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoadingScreen(),
    );
  }
}
