class VersionService {
  static const String version = '0.0.9';
  static const String buildNumber = '9';
  static const String appName = 'Nyooom Music';

  static String get fullVersion => '$version+$buildNumber';

  static String get aboutText => '''
$appName
Version: $version
Build: $buildNumber

A modern music player for your local music collection.
''';
}
