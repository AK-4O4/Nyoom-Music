import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/storage_service.dart';
import '../widgets/settings_tile.dart';
import 'package:file_picker/file_picker.dart';

class StorageSettingsScreen extends StatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  State<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends State<StorageSettingsScreen> {
  String? _currentStoragePath;
  int _totalStorageUsed = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final storageService = StorageService(prefs);
      final path = storageService.getStoragePath();
      setState(() {
        _currentStoragePath = path;
      });

      // Calculate total storage used
      int totalSize = 0;
      if (path != null) {
        final dir = Directory(path);
        if (await dir.exists()) {
          await for (final entity in dir.list(recursive: true)) {
            if (entity is File) {
              totalSize += await entity.length();
            }
          }
        }
      }

      setState(() {
        _totalStorageUsed = totalSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading storage info: $e')),
        );
      }
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

  Future<void> _changeStorageLocation() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Download Location',
      );

      if (selectedDirectory != null) {
        final prefs = await SharedPreferences.getInstance();
        final storageService = StorageService(prefs);
        await storageService.setStoragePath(selectedDirectory);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download location updated')),
          );
          _loadStorageInfo();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking directory: $e')),
        );
      }
    }
  }

  Future<void> _clearCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/cache');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cache cleared')),
          );
          _loadStorageInfo();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing cache: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                // Storage Usage Card
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Storage Usage',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total space used: ${_formatSize(_totalStorageUsed)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: _totalStorageUsed /
                              (1024 *
                                  1024 *
                                  1024), // Assuming 1GB max for visualization
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Storage Location
                SettingsTile(
                  title: 'Download Location',
                  subtitle: _currentStoragePath ?? 'Default location',
                  trailing: const Icon(Icons.folder_open),
                  onTap: _changeStorageLocation,
                  position: SettingsTilePosition.first,
                ),

                // Clear Cache
                SettingsTile(
                  title: 'Clear Cache',
                  subtitle: 'Remove temporary files',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _clearCache,
                  position: SettingsTilePosition.last,
                ),
              ],
            ),
    );
  }
}
