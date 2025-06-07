import 'package:flutter/material.dart';
import '../services/version_service.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Center(
            child: Icon(Icons.music_note,
                size: 80, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 24),
          const Text(
            VersionService.appName,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Version ${VersionService.version}',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 24),
          const Text(
            'A modern music player for your local music collection.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          const Text(
            'Features:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildFeatureItem('Local music playback'),
          _buildFeatureItem('Playlist management'),
          _buildFeatureItem('Dark/Light theme support'),
          const SizedBox(height: 24),
          const Text(
            'The app is still in development and some features may not work as expected.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 32),
          // License Section
          const Text(
            'License',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MIT License',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Copyright (c) 2025 Muhammad Abdullah',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '''Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.''',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Support Me',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'If you enjoy using this app, consider supporting its development:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.code),
                    title: const Text('Contribute on GitHub'),
                    onTap: () async {
                      // try {
                      //   final Uri url = Uri.parse(
                      //       'https://github.com/AK-4O4/music_app');
                      //   if (!await launchUrl(
                      //     url,
                      //     mode: LaunchMode.externalApplication,
                      //   )) {
                      //     if (context.mounted) {
                      //       ScaffoldMessenger.of(context).showSnackBar(
                      //         const SnackBar(
                      //           content: Text('Could not open GitHub'),
                      //           duration: Duration(seconds: 2),
                      //         ),
                      //       );
                      //     }
                      //   }
                      // } catch (e) {
                      //   if (context.mounted) {
                      //     ScaffoldMessenger.of(context).showSnackBar(
                      //       SnackBar(
                      //         content: Text('Error: $e'),
                      //         duration: const Duration(seconds: 2),
                      //       ),
                      //     );
                      //   }
                      // }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Dependencies Section
          const Text(
            'Dependencies',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildDependencyLicense(
            'Flutter',
            'BSD License',
            'Copyright 2014 The Flutter Authors. All rights reserved.',
          ),
          _buildDependencyLicense(
            'just_audio',
            'MIT License',
            'Copyright (c) 2019 Ryan Heise',
          ),
          _buildDependencyLicense(
            'path_provider',
            'BSD License',
            'Copyright 2013 The Flutter Authors. All rights reserved.',
          ),
          _buildDependencyLicense(
            'permission_handler',
            'MIT License',
            'Copyright (c) 2018 Baseflow',
          ),
          _buildDependencyLicense(
            'shared_preferences',
            'BSD License',
            'Copyright 2013 The Flutter Authors. All rights reserved.',
          ),
          _buildDependencyLicense(
            'url_launcher',
            'BSD License',
            'Copyright 2013 The Flutter Authors. All rights reserved.',
          ),
          _buildDependencyLicense(
            'youtube_explode_dart',
            'MIT License',
            'Copyright (c) 2019 Tyrrrz',
          ),
          _buildDependencyLicense(
            'youtube_music_api',
            'MIT License',
            'Copyright (c) 2023 Tyrrrz',
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '© ${DateTime.now().year} ${VersionService.appName}',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildDependencyLicense(
      String name, String license, String copyright) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(
          name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(license),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(copyright),
                const SizedBox(height: 8),
                const Text(
                  'This software is licensed under the terms of the license specified above.',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
