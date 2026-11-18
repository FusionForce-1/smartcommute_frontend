// Settings group
import 'package:flutter/material.dart';

import '../../config/theme_config.dart';

/// Settings group widget
class SettingsGroup extends StatelessWidget {
  /// Create settings group
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
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

/// Settings switch row
class SettingsSwitchRow extends StatelessWidget {
  /// Create settings switch row
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

  /// Build the widget
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

/// Settings link row
class SettingsLinkRow extends StatelessWidget {
  /// Create settings link row
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

  /// Build the widget
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
