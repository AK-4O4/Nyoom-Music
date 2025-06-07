import 'package:flutter/material.dart';

enum SettingsTilePosition {
  single, // Only one tile in the list
  first, // First tile in the list
  middle, // Middle tile in the list
  last, // Last tile in the list
}

class SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  final SettingsTilePosition position;

  const SettingsTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
    this.position = SettingsTilePosition.middle,
  });

  @override
  Widget build(BuildContext context) {
    // Get screen size
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    // Determine the border radius based on position
    BorderRadius borderRadius;
    switch (position) {
      case SettingsTilePosition.single:
        borderRadius = BorderRadius.circular(12);
        break;
      case SettingsTilePosition.first:
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        );
        break;
      case SettingsTilePosition.last:
        borderRadius = const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        );
        break;
      case SettingsTilePosition.middle:
        borderRadius = BorderRadius.zero;
        break;
    }

    return Container(
      margin: EdgeInsets.only(
        bottom: position == SettingsTilePosition.last ||
                position == SettingsTilePosition.single
            ? size.height * 0.01
            : 1,
        left: size.width * 0.02,
        right: size.width * 0.02,
        top: position == SettingsTilePosition.first ||
                position == SettingsTilePosition.single
            ? size.height * 0.01
            : 0,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: borderRadius,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: size.width * 0.04,
          vertical: size.height * 0.01,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 14,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
