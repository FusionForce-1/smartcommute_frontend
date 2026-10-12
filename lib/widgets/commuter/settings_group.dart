// lib/widgets/commuter/settings_group.dart
//
// Grouped white list used on the Profile tab, plus its two row types:
// a switch row (Notifications) and a link row (Account).

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Material (not a decorated box) so the rows' tap ripples show.
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: AppColors.divider, width: 1.4),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1.4, color: AppColors.divider),
            children[i],
          ],
        ],
      ),
    );
  }
}

class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppColors.brandTeal,
      title: Text(title, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
    );
  }
}

class SettingsLinkRow extends StatelessWidget {
  const SettingsLinkRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.brandTeal,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: color,
        child: Icon(icon, color: Colors.white, size: 22),
      ),
      title: Text(label, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 30),
    );
  }
}
