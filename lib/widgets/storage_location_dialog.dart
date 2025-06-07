import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(_selectedPath);
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
