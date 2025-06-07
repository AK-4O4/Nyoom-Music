import 'package:http/http.dart' as http;
import 'dart:convert';

class VersionService {
  static const String version = '0.0.9';
  static const String buildNumber = '9';
  static const String appName = 'Nyooom Music';
  static const String githubApiUrl =
      'https://api.github.com/repos/AK-4O4/Nyoom-Music/releases/latest';

  static String get fullVersion => '$version+$buildNumber';

  static String get aboutText => '''
$appName
Version: $version
Build: $buildNumber

A modern music player for your local music collection.
''';

  static Future<Map<String, dynamic>?> checkForUpdates() async {
    try {
      final response = await http.get(Uri.parse(githubApiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion =
            data['tag_name']?.toString().replaceAll('v', '') ?? '';
        final downloadUrl = data['assets']?[0]?['browser_download_url'] ?? '';
        final releaseNotes = data['body'] ?? '';

        // Compare versions
        final hasUpdate = _compareVersions(latestVersion, version) > 0;

        return {
          'hasUpdate': hasUpdate,
          'latestVersion': latestVersion,
          'currentVersion': version,
          'downloadUrl': downloadUrl,
          'releaseNotes': releaseNotes,
        };
      }
      return null;
    } catch (e) {
      print('Error checking for updates: $e');
      return null;
    }
  }

  static int _compareVersions(String version1, String version2) {
    final v1Parts = version1.split('.').map(int.parse).toList();
    final v2Parts = version2.split('.').map(int.parse).toList();

    for (var i = 0; i < 3; i++) {
      final v1 = i < v1Parts.length ? v1Parts[i] : 0;
      final v2 = i < v2Parts.length ? v2Parts[i] : 0;

      if (v1 > v2) return 1;
      if (v1 < v2) return -1;
    }
    return 0;
  }
}
