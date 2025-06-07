import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/settings_screen.dart';
import '../screens/about_screen.dart';
import '../services/version_service.dart';

AppBar appBarWidget(BuildContext context) {
  return AppBar(
    backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    actions: [
      PopupMenuButton<String>(
        itemBuilder: (context) => [
          PopupMenuItem(
            child: ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text(
                'Settings',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context); // Close the popup menu
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ),
          PopupMenuItem(
            child: ListTile(
              leading: const Icon(
                Icons.question_mark_rounded,
                color: Colors.white,
              ),
              title: const Text(
                'About',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                VersionService.version,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context); // Close the popup menu
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AboutScreen(),
                  ),
                );
              },
            ),
          ),
          PopupMenuItem(
            child: ListTile(
              leading: const Icon(Icons.help, color: Colors.white),
              title: const Text(
                'Help',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context); // Close the popup menu
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
            ),
          ),
        ],
        icon: const Icon(Icons.more_vert),
      ),
    ],
  );
}
