// lib/widgets/commuter/commuter_page_header.dart
//
// Teal header with a rounded bottom edge, a back arrow and a white title,
// for commuter pages opened on top of the dashboard (e.g. Find Routes).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme_config.dart';

class CommuterPageHeader extends StatelessWidget {
  const CommuterPageHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // white status-bar icons on teal
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.brandTeal,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppSpacing.md)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, AppSpacing.xs, AppSpacing.sm, AppSpacing.sm),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back_ios_new),
                  color: Colors.white,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
