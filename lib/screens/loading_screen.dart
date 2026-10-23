// lib/screens/loading_screen.dart
//
// Loading screen: the logo lockup with "Cebu City Transit Information" and a
// spinner on ice blue, shown while the app starts (loading .env and finding
// which backend answers — up to a minute if the cloud server is asleep).
// On web, web/index.html shows its HTML copy of this screen the whole time
// instead (see web_splash.dart), so only one loading screen ever appears.
// This Flutter one is what Android / iOS show.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../config/theme_config.dart';
import '../widgets/auth/smart_commute_logo.dart';
import 'web_splash.dart';

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
    if (!mounted) return;
    setState(() => _ready = true);
    // Lift the web page's HTML loading screen once the app's first real
    // screen is drawn beneath it.
    WidgetsBinding.instance.addPostFrameCallback((_) => removeWebSplash());
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
