// Loading screen
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../config/theme_config.dart';
import '../widgets/auth/smart_commute_logo.dart';
import 'web_splash.dart';

/// Loading screen
class LoadingScreen extends StatelessWidget {
  /// Create loading
  const LoadingScreen({super.key});

  static const double logoHeight = 220;

  /// Build the widget
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

/// App loader widget
class AppLoader extends StatefulWidget {
  /// Create app loader
  const AppLoader({super.key, required this.load, required this.builder});

  final Future<void> Function() load;
  final WidgetBuilder builder;

  /// Create widget state
  @override
  State<AppLoader> createState() => _AppLoaderState();
}

/// App loader state
class _AppLoaderState extends State<AppLoader> {
  bool _ready = false;

  /// Initialize widget state
  @override
  void initState() {
    super.initState();
    _start();
  }

  /// Start app loader
  Future<void> _start() async {
    try {
      await widget.load();
    } catch (e) {
      debugPrint('Startup failed: $e');
    }
    if (!mounted) return;
    setState(() => _ready = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => removeWebSplash());
  }

  /// Build the widget
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
