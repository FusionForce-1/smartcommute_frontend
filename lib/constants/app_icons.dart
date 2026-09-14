// lib/constants/app_icons.dart
//
// Single source of truth for every icon used across the Smart Commute
// Flutter app (screens/, widgets/). Import this file wherever an icon is
// needed instead of writing `Icons.xxx` inline — that way an icon only
// ever has to be changed in one place.
//
// Usage:
//   import '../../constants/app_icons.dart';
//   Icon(AppIcons.email)
//
// Google's "G" logo is not a Material icon, so AppIcons.googleAsset points to
// a bundled asset instead of an IconData — see `googleAsset` below.

import 'package:flutter/material.dart';

class AppIcons {
  AppIcons._(); // no instances — static constants only

  // ---- Auth screens (Login / Register / Forgot Password / Verify OTP) ----
  static const IconData email = Icons.email_outlined;
  static const IconData person = Icons.person_outline;
  static const IconData lock = Icons.lock_outline;
  static const IconData passwordVisible = Icons.visibility_outlined;
  static const IconData passwordHidden = Icons.visibility_off_outlined;
  static const IconData checkboxOn = Icons.check_box;
  static const IconData checkboxOff = Icons.check_box_outline_blank;
  static const IconData forgotKey = Icons.vpn_key_outlined;
  static const IconData forgotShield = Icons.shield_outlined;
  static const IconData otpEnvelope = Icons.mark_email_unread_outlined;
  static const IconData back = Icons.arrow_back_ios_new;
  static const IconData close = Icons.close;

  /// Google's "G" logo — not a Material icon; bundled as an asset.
  /// Referenced instead of an IconData: SvgPicture.asset(AppIcons.googleAsset).
  static const String googleAsset = 'assets/icons/google_logo.svg';

  // ---- Navigation / shared chrome ----
  static const IconData notificationBell = Icons.notifications_outlined;
  static const IconData profileAvatar = Icons.account_circle_outlined;
  static const IconData logout = Icons.logout;
  static const IconData settings = Icons.settings_outlined;

  // ---- Commuter: Map / Routes / Feedback / Announcements ----
  static const IconData location = Icons.location_on_outlined;
  static const IconData myLocation = Icons.my_location;
  static const IconData search = Icons.search;
  static const IconData routeStop = Icons.pin_drop_outlined;
  static const IconData feedback = Icons.report_gmailerrorred_outlined;
  static const IconData announcement = Icons.campaign_outlined;
  static const IconData fare = Icons.payments_outlined;

  // ---- Vehicles / fleet / status ----
  static const IconData vehicle = Icons.directions_bus_filled_outlined;
  static const IconData signalLost = Icons.signal_wifi_off;
  static const IconData crowdLow = Icons.person_outline;
  static const IconData crowdMedium = Icons.people_outline;
  static const IconData crowdHigh = Icons.groups_outlined;
  static const IconData statusActive = Icons.check_circle_outline;
  static const IconData statusCongested = Icons.warning_amber_outlined;
  static const IconData statusSuspended = Icons.cancel_outlined;

  // ---- Driver ----
  static const IconData gpsToggleOn = Icons.gps_fixed;
  static const IconData gpsToggleOff = Icons.gps_off;
  static const IconData speed = Icons.speed_outlined;
  static const IconData heading = Icons.explore_outlined;

  // ---- Generic feedback / state widgets ----
  static const IconData errorRetry = Icons.refresh;
  static const IconData emptyState = Icons.inbox_outlined;
  static const IconData confirmWarning = Icons.help_outline;
}
