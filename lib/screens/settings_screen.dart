import 'package:flutter/material.dart';
import 'package:nyooom/screens/about_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/theme_service.dart';
import '../services/version_service.dart';
import '../widgets/settings_tile.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/storage_service.dart';
import '../widgets/storage_location_dialog.dart';
import '../screens/storage_settings_screen.dart';
import 'package:flutter_app_update/flutter_app_update.dart';
import 'package:flutter_app_update/result_model.dart';
//import 'package:app_settings/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = true;
  Color _primaryColor = ThemeService.themeColors['Purple']!;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final isDark = await ThemeService.getThemeMode() == ThemeMode.dark;
    final primaryColor = await ThemeService.getPrimaryColor();
    setState(() {
      _isDarkMode = isDark;
      _primaryColor = primaryColor;
    });
  }

  Future<void> _toggleTheme(bool value) async {
    await ThemeService.setThemeMode(value);
    setState(() {
      _isDarkMode = value;
    });
  }

  Future<void> _setPrimaryColor(Color color) async {
    await ThemeService.setPrimaryColor(color);
    setState(() {
      _primaryColor = color;
    });
  }

  void _restartApp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart App'),
        content: const Text(
            'Are you sure you want to restart the app to apply theme changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              exit(0); // This will close the app
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  Widget _buildColorOption(Color color, String name) {
    final isSelected = _primaryColor == color;
    return GestureDetector(
      onTap: () => _setPrimaryColor(color),
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
      ),
    );
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      // Initialize the update listener
      AzhonAppUpdate.listener((ResultModel model) {
        debugPrint('Update status: $model');
      });

      // Create update model
      final updateModel = UpdateModel(
        "https://github.com/AK-4O4/nyoom_music/releases/latest/download/app-release.apk",
        "nyoom_music.apk",
        "ic_launcher",
        "https://github.com/AK-4O4/nyoom_music/releases/latest",
      );

      // Show update dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Check for Updates'),
            content: const Text('Would you like to check for updates?'),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text('Check'),
                onPressed: () {
                  Navigator.of(context).pop();
                  AzhonAppUpdate.update(updateModel);
                },
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking for updates: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    AzhonAppUpdate.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // Theme Mode
          const Padding(
            padding: EdgeInsets.only(left: 16.0, right: 16),
            child: Text(
              'Note: Restart The App To Apply Theme Changes',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),

          const SizedBox(height: 16),
          SettingsTile(
            title: 'Dark Mode',
            subtitle: 'Toggle between light and dark theme',
            trailing: Switch(
              value: _isDarkMode,
              onChanged: _toggleTheme,
            ),
            position: SettingsTilePosition.single,
          ),
          const SizedBox(height: 16),

          // Primary Color
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Theme Color',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose your preferred theme color',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ThemeService.themeColors.entries.map((entry) {
                      return _buildColorOption(entry.value, entry.key);
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton.icon(
                    onPressed: _restartApp,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Restart App'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          const Padding(
            padding: EdgeInsets.only(left: 30.0, right: 30),
            child: Divider(),
          ),
          const SizedBox(
            height: 16,
          ),

          // More settings
          SettingsTile(
            title: 'Storage',
            subtitle: 'Manage downloaded music and cache',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StorageSettingsScreen(),
                ),
              );
            },
            position: SettingsTilePosition.first,
          ),
          SettingsTile(
            title: 'Permissions',
            subtitle: 'Manage app permissions',
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await openAppSettings();
            },
            position: SettingsTilePosition.middle,
          ),
          SettingsTile(
            title: 'Playback',
            subtitle: 'Audio quality and playback settings',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Playback Settings'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.audio_file),
                        title: const Text('Audio Quality'),
                        subtitle: const Text('Set streaming quality'),
                        onTap: () {
                          // TODO: Implement audio quality settings
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.download),
                        title: const Text('Download Quality'),
                        subtitle: const Text('Set download quality'),
                        onTap: () {
                          // TODO: Implement download quality settings
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
            position: SettingsTilePosition.middle,
          ),
          SettingsTile(
            title: 'Check for Updates',
            subtitle: 'Check for the latest version',
            trailing: _isCheckingUpdate
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.system_update),
            onTap: _isCheckingUpdate ? null : _checkForUpdates,
            position: SettingsTilePosition.last,
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 30.0, right: 30),
            child: Divider(),
          ),
          const SizedBox(
            height: 16,
          ),
          SettingsTile(
            title: 'About',
            subtitle: 'Version: ${VersionService.version}',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop(context); // Close the popup menu
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AboutScreen(),
                ),
              );
            },
            position: SettingsTilePosition.first,
          ),
          SettingsTile(
            title: 'Help',
            subtitle: 'About App',
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              try {
                final Uri url =
                    Uri.parse('https://github.com/AK-4O4?tab=repositories');
                if (!await launchUrl(
                  url,
                  mode: LaunchMode.externalApplication,
                  webViewConfiguration: const WebViewConfiguration(
                    enableJavaScript: true,
                    enableDomStorage: true,
                  ),
                )) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Could not open the URL. Please try again.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error opening URL: $e'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            position: SettingsTilePosition.last,
          ),
        ],
      ),
    );
  }
}
