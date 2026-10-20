// lib/screens/commuter/help_support_screen.dart
//
// Help & Support (Profile → Account): answers to common questions, the
// User Agreement / Privacy Policy, and "Email us" once a support address
// is set in lib/constants/support.dart.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../constants/legal_text.dart';
import '../../constants/support.dart';
import '../../widgets/auth/consent_checkbox.dart';
import '../../widgets/commuter/settings_group.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const faqs = [
    (
      'How do I plan a trip?',
      'Open the Route tab, choose From and To (and a departure time if you like), then tap '
          'Find Routes. Each suggested public utility vehicle (PUV) route shows the fare '
          'estimate and travel time.',
    ),
    (
      'How do I see where the PUVs are right now?',
      'The Home tab shows the live map. PUVs with a GPS tracker appear on it and move as '
          'they drive. A PUV that is off duty or out of signal will not show.',
    ),
    (
      'Are the fares exact?',
      'Fares are estimates based on LTFRB fare rules and the distance you ride. '
          'The fare you pay the driver can differ slightly.',
    ),
    (
      'How do I save a route I ride often?',
      'Go to Profile → Saved Routes and tap "+ Add". Tap a saved route to plan it again. '
          'Press and hold one to remove it.',
    ),
    (
      'How do I rate a ride or a driver?',
      'Go to Profile → Rate Your Ride and tap "Write a review". Choose the route and PUV, '
          'give a star rating, and add tags or a comment. Operators see your review '
          'without your name.',
    ),
    (
      'Why am I not getting alerts?',
      'Check Profile → Notifications. Route Alerts and Schedule Updates must be turned on, '
          'and notifications must be allowed for SmartCommute in your phone settings.',
    ),
    (
      'I forgot my password.',
      'Sign out, then tap "Forgot Password?" on the sign-in screen. We will email you a '
          'code to set a new password.',
    ),
    (
      'How do I get a copy of my data or delete my account?',
      'Under the Data Privacy Act you can ask for a copy of your data, or for it to be '
          'corrected or deleted. Contact us with the email address on your account and we '
          'will handle your request.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundIceBlue,
      appBar: AppBar(
        backgroundColor: AppColors.brandTeal,
        foregroundColor: Colors.white,
        title: const Text('Help & Support'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          const _Heading('Frequently asked questions'),
          SettingsGroup(
            children: [
              for (final (question, answer) in faqs)
                ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  iconColor: AppColors.brandTeal,
                  title: Text(
                    question,
                    style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(answer, style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary)),
                  ],
                ),
            ],
          ),
          if (hasSupportEmail) ...[
            const SizedBox(height: AppSpacing.md),
            const _Heading('Still need help?'),
            SettingsGroup(
              children: [
                SettingsLinkRow(
                  icon: Icons.mail_outline,
                  label: 'Email us',
                  onTap: () => emailSupport(context, subject: 'SmartCommute help'),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const _Heading('Legal'),
          SettingsGroup(
            children: [
              SettingsLinkRow(
                icon: Icons.description_outlined,
                label: 'User Agreement',
                onTap: () => showLegalDoc(context, userAgreement),
              ),
              SettingsLinkRow(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                onTap: () => showLegalDoc(context, privacyPolicy),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
      ),
    );
  }
}
