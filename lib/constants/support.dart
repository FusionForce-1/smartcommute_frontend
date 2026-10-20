// lib/constants/support.dart
//
// Where commuters reach the SmartCommute team (Help & Support "Email us",
// and data requests from Privacy & Security).

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// TODO(team): put the team's support address here, e.g. a shared Gmail.
/// While it is empty, the "Email us" options are hidden.
const String supportEmail = '';

bool get hasSupportEmail => supportEmail.isNotEmpty;

/// Opens the phone's email app addressed to [supportEmail].
Future<void> emailSupport(BuildContext context, {required String subject}) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri(
    scheme: 'mailto',
    path: supportEmail,
    // Uri encodes spaces in queryParameters as "+", which mail apps show
    // literally; build the query by hand so they become %20.
    query: 'subject=${Uri.encodeComponent(subject)}',
  );
  bool opened = false;
  try {
    opened = await launchUrl(uri);
  } catch (_) {}
  if (!opened) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No email app found. Write to us at $supportEmail.')),
    );
  }
}
