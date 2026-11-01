// lib/widgets/driver/crowd_estimate_card.dart
//
// How full the vehicle is, from Empty to Full. The value is saved when the
// driver lets go of the slider, not on every step of the drag. Without the
// callbacks (off shift) it's shown but locked.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import 'driver_card.dart';

class CrowdEstimateCard extends StatelessWidget {
  const CrowdEstimateCard({
    super.key,
    required this.percent,
    this.onChanged,
    this.onChangeEnd,
  });

  final int percent;

  /// Null while off shift: the slider is locked.
  final ValueChanged<int>? onChanged;
  final ValueChanged<int>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    const hint = TextStyle(fontSize: 13, color: AppColors.navInactive);
    return DriverCard(
      title: 'Crowd Activity Estimate',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.panelGrey,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Text('$percent% Full', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
      ),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 18,
              activeTrackColor: AppColors.textPrimary,
              inactiveTrackColor: AppColors.panelGrey,
              thumbColor: Colors.white,
              disabledActiveTrackColor: AppColors.navInactive,
              disabledInactiveTrackColor: AppColors.panelGrey,
              disabledThumbColor: Colors.white,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const _OutlinedThumb(),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: percent.toDouble(),
              max: 100,
              divisions: 20,
              semanticFormatterCallback: (v) => '${v.round()}% full',
              onChanged: onChanged == null ? null : (v) => onChanged!(v.round()),
              onChangeEnd: onChangeEnd == null ? null : (v) => onChangeEnd!(v.round()),
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('Empty', style: hint), Text('Full', style: hint)],
          ),
        ],
      ),
    );
  }
}

/// White circle with a dark outline, as in the design.
class _OutlinedThumb extends SliderComponentShape {
  const _OutlinedThumb();

  static const double _radius = 11;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size.fromRadius(_radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, _radius, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      _radius,
      Paint()
        ..color = AppColors.textSecondary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}
