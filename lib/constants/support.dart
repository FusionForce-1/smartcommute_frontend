// Support constants
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const String supportEmail = '';

bool get hasSupportEmail => supportEmail.isNotEmpty;

/// Email support
Future<void> emailSupport(BuildContext context, {required String subject}) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri(
    scheme: 'mailto',
    path: supportEmail,
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
