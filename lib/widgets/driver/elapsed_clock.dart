// lib/widgets/driver/elapsed_clock.dart
//
// "01:20:04" since [since], ticking every second.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../utils/shift_time.dart';

class ElapsedClock extends StatefulWidget {
  const ElapsedClock({super.key, required this.since, this.style});

  final DateTime since;
  final TextStyle? style;

  /// Monospaced digits, as in the design.
  static const TextStyle monoStyle = TextStyle(
    fontFamily: 'monospace',
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  @override
  State<ElapsedClock> createState() => _ElapsedClockState();
}

class _ElapsedClockState extends State<ElapsedClock> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      formatClock(DateTime.now().difference(widget.since)),
      style: ElapsedClock.monoStyle.merge(widget.style),
    );
  }
}
