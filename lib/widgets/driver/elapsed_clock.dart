// Elapsed clock
import 'dart:async';

import 'package:flutter/material.dart';

import '../../utils/shift_time.dart';

/// Elapsed clock widget
class ElapsedClock extends StatefulWidget {
  /// Create elapsed clock
  const ElapsedClock({super.key, required this.since, this.style});

  final DateTime since;
  final TextStyle? style;

  static const TextStyle monoStyle = TextStyle(
    fontFamily: 'monospace',
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Create widget state
  @override
  State<ElapsedClock> createState() => _ElapsedClockState();
}

/// Elapsed clock state
class _ElapsedClockState extends State<ElapsedClock> {
  late final Timer _timer;

  /// Initialize widget state
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  /// Clean up resources
  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return Text(
      formatClock(DateTime.now().difference(widget.since)),
      style: ElapsedClock.monoStyle.merge(widget.style),
    );
  }
}
