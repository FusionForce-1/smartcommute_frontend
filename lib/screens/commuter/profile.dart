// Profile screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';
import '../../models/commuter_profile.dart';
import '../../models/ride_review.dart';
import '../../models/vehicles.dart';
import '../../models/transport_model.dart';
import '../../models/transport_stop.dart';
import '../../providers/load_state.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/auth/consent_checkbox.dart';
import '../../widgets/commuter/commuter_primary_button.dart';
import '../../widgets/commuter/profile_header.dart';
import '../../widgets/commuter/review_ride_sheet.dart';
import '../../widgets/commuter/save_route_sheet.dart';
import '../../widgets/commuter/saved_route_tile.dart';
import '../../widgets/commuter/settings_group.dart';
import 'help_support_screen.dart';
import 'privacy_security_screen.dart';

/// Profile tab
class ProfileTab extends StatelessWidget {
  /// Create profile tab
  const ProfileTab({
    super.key,
    required this.isGuest,
    required this.stops,
    required this.routes,
    this.vehicles = const [],
    required this.onOpenSavedRoute,
    required this.onSignOut,
    required this.onCreateAccount,
  });

  final bool isGuest;
  final List<TransportStop> stops;
  final List<TransportRoute> routes;

  final List<Vehicle> vehicles;

  final ValueChanged<SavedRoute> onOpenSavedRoute;

  final VoidCallback onSignOut;

  final VoidCallback onCreateAccount;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    if (isGuest) {
      return _GuestProfile(onSignIn: onSignOut, onCreateAccount: onCreateAccount);
    }

    final profile = context.watch<ProfileProvider>();
    final data = profile.profile;
    if (data == null) {
      return profile.state == LoadState.error
          ? _LoadError(message: profile.errorMessage, onRetry: profile.load)
          : const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: profile.load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          ProfileHeader(profile: data, onEditName: () => _editName(context, data.name)),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionTitle('Rate Your Ride'),
                _RateYourRide(
                  reviews: profile.reviews,
                  onWrite: () => _writeReview(context, profile),
                ),
                const SizedBox(height: AppSpacing.sm),
                _SectionTitle(
                  'Saved Routes',
                  action: TextButton(
                    onPressed: () => showSaveRouteSheet(
                      context,
                      profile: profile,
                      stops: stops,
                      routes: routes,
                    ),
                    style: TextButton.styleFrom(foregroundColor: AppColors.brandTeal),
                    child: const Text('+ Add', style: TextStyle(fontSize: 17)),
                  ),
                ),
                if (profile.savedRoutes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text('No saved routes yet. Tap "+ Add" to save one you ride often.'),
                  ),
                for (final route in profile.savedRoutes)
                  SavedRouteTile(
                    route: route,
                    onTap: () => onOpenSavedRoute(route),
                    onLongPress: () => _confirmRemove(context, route),
                  ),
                const SizedBox(height: AppSpacing.sm),
                const _SectionTitle('Notifications'),
                SettingsGroup(
                  children: [
                    for (final pref in NotificationPref.values)
                      SettingsSwitchRow(
                        title: pref.title,
                        subtitle: pref.subtitle,
                        value: profile.isEnabled(pref),
                        onChanged: (on) => _report(context, profile.setNotificationPref(pref, on)),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const _SectionTitle('Account'),
                SettingsGroup(
                  children: [
                    SettingsLinkRow(
                      icon: Icons.shield_outlined,
                      label: 'Privacy & Security',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => PrivacySecurityScreen(service: profile.service),
                      )),
                    ),
                    ..._infoLinks(context),
                    SettingsLinkRow(
                      icon: AppIcons.logout,
                      label: 'Sign out',
                      color: AppColors.error,
                      onTap: onSignOut,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Edit name
  Future<void> _editName(BuildContext context, String current) async {
    final profile = context.read<ProfileProvider>();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(initial: current),
    );
    if (name == null || name.trim().isEmpty || name.trim() == current || !context.mounted) return;
    await _report(context, profile.rename(name));
  }

  /// Write review
  Future<void> _writeReview(BuildContext context, ProfileProvider profile) async {
    if (routes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Routes are still loading. Please try again in a moment.')),
      );
      return;
    }
    final sent = await showReviewRideSheet(context, profile: profile, routes: routes, vehicles: vehicles);
    if (sent == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks! Your review was sent to the operator.')),
      );
    }
  }

  /// Confirm remove
  Future<void> _confirmRemove(BuildContext context, SavedRoute route) async {
    final profile = context.read<ProfileProvider>();
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove saved route?'),
        content: Text('"${route.label}" will be removed from your profile.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove == true && context.mounted) await _report(context, profile.removeSavedRoute(route));
  }

  /// Report profile tab
  Future<void> _report(BuildContext context, Future<String?> change) async {
    final error = await change;
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

}

/// Info links
List<Widget> _infoLinks(BuildContext context) => [
      SettingsLinkRow(
        icon: Icons.help_outline,
        label: 'Help & Support',
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const HelpSupportScreen(),
        )),
      ),
      SettingsLinkRow(
        icon: Icons.description_outlined,
        label: 'Terms & Privacy Policy',
        onTap: () => showLegalChoices(context),
      ),
    ];

/// Rate your ride widget
class _RateYourRide extends StatelessWidget {
  /// Create rate your ride
  const _RateYourRide({required this.reviews, required this.onWrite});

  final List<RideReview> reviews;
  final VoidCallback onWrite;

  /// Rate your stars
  static String _stars(int n) => '${'★' * n}${'☆' * (5 - n)}';

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        border: Border.all(color: AppColors.divider, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.brandTeal,
                foregroundColor: Colors.white,
                child: Icon(Icons.rate_review_outlined),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text(
                  'How was your PUV ride? Rate the driver and the vehicle — it helps operators improve.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: onWrite,
            style: FilledButton.styleFrom(backgroundColor: AppColors.brandTeal),
            icon: const Icon(Icons.star_rounded),
            label: const Text('Write a review'),
          ),
          for (final r in reviews.take(2)) ...[
            const Divider(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_stars(r.rating), style: const TextStyle(color: Color(0xFFF5A623), fontSize: 15)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [r.routeCode, r.plateNumber].whereType<String>().join(' · '),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (r.comment != null || r.tags.isNotEmpty)
                        Text(
                          r.comment ?? r.tags.map(ReviewTag.labelOf).join(', '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Section title widget
class _SectionTitle extends StatelessWidget {
  /// Create section title
  const _SectionTitle(this.title, {this.action});

  final String title;
  final Widget? action;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Padding(
      padding: EdgeInsets.only(bottom: action == null ? AppSpacing.xs : 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }
}

/// Edit name dialog
class _EditNameDialog extends StatefulWidget {
  /// Create edit name dialog
  const _EditNameDialog({required this.initial});

  final String initial;

  /// Create widget state
  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

/// Edit name dialog state
class _EditNameDialogState extends State<_EditNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  /// Clean up resources
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 60,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Your name'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, _controller.text), child: const Text('Save')),
      ],
    );
  }
}

/// Load error widget
class _LoadError extends StatelessWidget {
  /// Create load error
  const _LoadError({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.errorRetry, size: 44, color: AppColors.error),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message ?? "Couldn't load your profile.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

/// Guest profile widget
class _GuestProfile extends StatelessWidget {
  /// Create guest profile
  const _GuestProfile({required this.onSignIn, required this.onCreateAccount});

  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;

  static const _perks = [
    (Icons.bookmark_border, 'Save the routes you ride often'),
    (Icons.history, 'Keep track of your trips'),
    (Icons.star_border, 'Rate your rides'),
    (Icons.notifications_none, 'Choose which alerts you get'),
  ];

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SizedBox(height: AppSpacing.sm),
          const Icon(AppIcons.navProfile, size: 72, color: AppColors.brandTeal),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            "You're browsing as a guest",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'You can view the live map and plan trips as a guest. Sign in to:',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final (icon, text) in _perks)
            ListTile(
              dense: true,
              leading: Icon(icon, color: AppColors.brandTeal),
              title: Text(text, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
            ),
          const SizedBox(height: AppSpacing.sm),
          CommuterPrimaryButton(label: 'Sign in', onPressed: onSignIn),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: onCreateAccount,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brandTeal,
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: AppColors.brandTeal, width: 1.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w600),
            ),
            child: const Text('Create an account'),
          ),
          const SizedBox(height: AppSpacing.lg),
          SettingsGroup(children: _infoLinks(context)),
        ],
      ),
    );
  }
}
