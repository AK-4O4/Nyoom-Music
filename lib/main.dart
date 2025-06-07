import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'screens/home_screen.dart';
import 'services/audio_handler.dart';
import 'services/permission_service.dart';
import 'services/storage_service.dart';
import 'services/theme_service.dart';

late CustomAudioHandler audioHandler;
late StorageService storageService;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set the preferred orientations
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Set global system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.black.withOpacity(0.3),
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize services
  audioHandler = await AudioService.init(
    builder: () => NyooomAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.nyoom.music.channel.audio',
      androidNotificationChannelName: 'Nyoom Music',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  storageService = await StorageService.create();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = true;
  Color _primaryColor = ThemeService.themeColors['Purple']!;

  @override
  void initState() {
    super.initState();
    _loadThemePreferences();
  }

  Future<void> _loadThemePreferences() async {
    final isDark = await ThemeService.getThemeMode() == ThemeMode.dark;
    final primaryColor = await ThemeService.getPrimaryColor();
    setState(() {
      _isDarkMode = isDark;
      _primaryColor = primaryColor;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nyoom Music',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: _primaryColor,
          onPrimary: Colors.white,
          secondary: _primaryColor.withOpacity(0.7),
          tertiary: _primaryColor.withOpacity(0.5),
          surface: Colors.white,
          error: const Color(0xFFB3261E),
        ),
        scaffoldBackgroundColor: Colors.white,
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: _primaryColor,
          onPrimary: Colors.white,
          secondary: _primaryColor.withOpacity(0.7),
          tertiary: _primaryColor.withOpacity(0.5),
          surface: const Color.fromARGB(255, 42, 41, 46),
          error: const Color(0xFFB3261E),
        ),
        scaffoldBackgroundColor: const Color(0xFF1C1B1F),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color.fromARGB(255, 42, 41, 46),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1C1B1F),
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const PermissionGateScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PermissionGateScreen extends StatefulWidget {
  const PermissionGateScreen({super.key});

  @override
  State<PermissionGateScreen> createState() => _PermissionGateScreenState();
}

class _PermissionGateScreenState extends State<PermissionGateScreen> {
  final PermissionService _permissionService = PermissionService();
  bool _checkingPermissions = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    if (!mounted) return;

    setState(() {
      _checkingPermissions = true;
      _errorMessage = '';
    });

    try {
      print('Checking permissions...');
      final hasPermissions = await _permissionService.requestAllPermissions(
        context,
      );

      if (!mounted) return;

      setState(() {
        _checkingPermissions = false;
      });

      if (hasPermissions) {
        print('Permissions granted, navigating to HomeScreen');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        setState(() {
          _errorMessage = 'Please grant all required permissions to continue';
        });
      }
    } catch (e) {
      print('Error during permission check: $e');
      if (!mounted) return;
      setState(() {
        _checkingPermissions = false;
        _errorMessage = 'Error checking permissions: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: _checkingPermissions
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Checking permissions...'),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Storage and notification permissions are required',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _checkPermissions,
                      child: const Text('Grant Permissions'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class StorageLocationDialog extends StatefulWidget {
  const StorageLocationDialog({super.key});

  @override
  State<StorageLocationDialog> createState() => _StorageLocationDialogState();
}

class _StorageLocationDialogState extends State<StorageLocationDialog> {
  String? _selectedPath;
  bool _isLoading = true;
  List<Directory> _availableLocations = [];

  @override
  void initState() {
    super.initState();
    _loadStorageLocations();
  }

  Future<void> _loadStorageLocations() async {
    try {
      final List<Directory> locations = [];

      // Add internal storage
      final appDir = await getApplicationDocumentsDirectory();
      locations.add(appDir);

      // Add external storage if available
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          locations.add(externalDir);
        }
      } catch (_) {
        // External storage might not be available
      }

      setState(() {
        _availableLocations = locations;
        _selectedPath = locations.first.path;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatSize(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Download Location'),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose where you want to store your downloaded music:',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                ..._availableLocations.map((directory) {
                  final isInternal = directory.path.contains('data/data');
                  final label = isInternal ? 'Internal Storage' : 'SD Card';
                  final stat = directory.statSync();

                  return RadioListTile<String>(
                    title: Text(label),
                    subtitle: Text('Size: ${_formatSize(stat.size)}'),
                    value: directory.path,
                    groupValue: _selectedPath,
                    onChanged: (String? value) {
                      setState(() {
                        _selectedPath = value;
                      });
                    },
                  );
                }),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(_selectedPath);
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
