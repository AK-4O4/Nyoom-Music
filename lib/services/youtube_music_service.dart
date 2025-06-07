import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'dart:async';
import '../models/song_model.dart';
import '../models/album_model.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io';
import 'dart:async';

class YoutubeMusicService {
  final YTMusic _ytMusic = YTMusic();
  final YoutubeExplode _youtubeExplode = YoutubeExplode();
  bool _isInitialized = false;

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _ytMusic.initialize();
      _isInitialized = true;
    }
  }

  Future<List<String>> getSearchSuggestions(String query) async {
    try {
      await _ensureInitialized();
      return await _ytMusic.getSearchSuggestions(query);
    } catch (e) {
      print('Error getting search suggestions: $e');
      return [];
    }
  }

  Future<String?> getLyrics(String videoId) async {
    try {
      await _ensureInitialized(); //TODO: UPDATE TO TIMED LYRICS
      return await _ytMusic.getLyrics(videoId);
    } catch (e) {
      print('Error getting lyrics: $e');
      return null;
    }
  }

  Future<List<Song>> searchSongs(String query) async {
    try {
      await _ensureInitialized();
      final results = await _ytMusic.searchSongs(query);

      return results
          .map(
            (item) => Song(
              id: item.videoId,
              title: item.name,
              artist: item.artist.name,
              thumbnailUrl: _getThumbnailUrl(item),
              isOffline: false,
              filePath: null,
            ),
          )
          .toList();
    } catch (e) {
      print('Error searching songs: $e');
      throw Exception('Failed to search songs');
    }
  }

  String _getThumbnailUrl(dynamic item) {
    try {
      if (item.thumbnails != null && item.thumbnails.isNotEmpty) {
        return item.thumbnails.first.url ?? '';
      }
    } catch (_) {}
    return '';
  }

  Future<List<Song>> getTopSongs() async {
    try {
      await _ensureInitialized();

      // Try to get top songs from search
      try {
        final results = await _ytMusic.searchSongs('top hits this week');
        if (results.isNotEmpty) {
          return results
              .take(20)
              .map(
                (item) => Song(
                  id: item.videoId,
                  title: item.name,
                  artist: item.artist.name,
                  thumbnailUrl: _getThumbnailUrl(item),
                  isOffline: false,
                  filePath: null,
                ),
              )
              .toList();
        }
      } catch (e) {
        print(
          'Error getting top songs from search, falling back to home sections: $e',
        );
      }

      // Fallback to home sections
      final homeSections = await _ytMusic.getHomeSections();
      final topSongs = homeSections
          .where(
            (section) =>
                (section.title.toLowerCase().contains('trend')) ||
                (section.title.toLowerCase().contains('top')) ||
                (section.title.toLowerCase().contains('popular')),
          )
          .expand((section) => section.contents)
          .where((item) => item.type == 'song')
          .take(20)
          .toList();

      if (topSongs.isEmpty) {
        // If still no songs, try another search
        final results = await _ytMusic.searchSongs('Top songs');
        return results
            .take(20)
            .map(
              (item) => Song(
                id: item.videoId,
                title: item.name,
                artist: item.artist.name,
                thumbnailUrl: _getThumbnailUrl(item),
                isOffline: false,
                filePath: null,
              ),
            )
            .toList();
      }

      return topSongs
          .map(
            (item) => Song(
              id: item.videoId ?? '',
              title: item.name ?? 'Unknown Title',
              artist: item.artist?.name ?? 'Unknown Artist',
              thumbnailUrl: _getThumbnailUrl(item),
              isOffline: false,
              filePath: null,
            ),
          )
          .toList();
    } catch (e) {
      print('Error getting top songs: $e');
      throw Exception('Failed to get top songs');
    }
  }

  Future<Stream<List<int>>> getAudioStream(String videoId) async {
    try {
      final manifest = await _youtubeExplode.videos.streamsClient.getManifest(
        videoId,
      );
      final audioOnly = manifest.audioOnly;
      final streamInfo = audioOnly.withHighestBitrate();
      return _youtubeExplode.videos.streamsClient.get(streamInfo);
    } catch (e) {
      print('Error getting audio stream: $e');
      throw Exception('Failed to get audio stream');
    }
  }

  Future<String?> downloadSong(
    String videoId, {
    Function(double)? onProgress,
  }) async {
    try {
      // Get video info first
      final video = await _youtubeExplode.videos.get(videoId);
      if (video == null) {
        throw Exception('Could not get video information');
      }

      // Get audio stream
      final manifest =
          await _youtubeExplode.videos.streamsClient.getManifest(videoId);
      final audioOnly = manifest.audioOnly;
      if (audioOnly.isEmpty) {
        throw Exception('No audio stream available');
      }

      // Get highest quality audio stream
      final streamInfo = audioOnly.reduce(
          (a, b) => a.bitrate.bitsPerSecond > b.bitrate.bitsPerSecond ? a : b);

      // Create downloads directory
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${directory.path}/Music');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Generate filename
      final filename =
          '${video.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}.mp3';
      final filePath = '${downloadsDir.path}/$filename';

      // Download audio stream
      final stream = _youtubeExplode.videos.streamsClient.get(streamInfo);
      final file = File(filePath);
      final fileStream = file.openWrite();
      final len = streamInfo.size.totalBytes;
      var count = 0;

      try {
        await for (final data in stream) {
          count += data.length;
          if (onProgress != null) {
            onProgress(count / len);
          }
          fileStream.add(data);
        }
        await fileStream.flush();
        await fileStream.close();

        // Download and embed artwork
        final thumbnailUrl = video.thumbnails.highResUrl;
        if (thumbnailUrl != null) {
          try {
            final response = await http.get(Uri.parse(thumbnailUrl));
            if (response.statusCode == 200) {
              final tempArtworkPath = '${directory.path}/temp_artwork.jpg';
              await File(tempArtworkPath).writeAsBytes(response.bodyBytes);

              // Use ffmpeg to embed artwork
              final result = await Process.run('ffmpeg', [
                '-i',
                filePath,
                '-i',
                tempArtworkPath,
                '-map',
                '0:0',
                '-map',
                '1:0',
                '-c',
                'copy',
                '-id3v2_version',
                '3',
                '-metadata:s:v',
                'title=Album cover',
                '-metadata:s:v',
                'comment=Cover (front)',
                '${filePath}_with_artwork.mp3'
              ]);

              if (result.exitCode == 0) {
                // Replace original file with the one containing artwork
                await File(filePath).delete();
                await File('${filePath}_with_artwork.mp3').rename(filePath);
              }

              // Clean up temporary artwork file
              await File(tempArtworkPath).delete();
            }
          } catch (e) {
            print('Error embedding artwork: $e');
            // Continue even if artwork embedding fails
          }
        }

        return filePath;
      } catch (e) {
        // Clean up the file if download fails
        if (await file.exists()) {
          await file.delete();
        }
        rethrow;
      }
    } catch (e) {
      print('Error downloading song: $e');
      return null;
    }
  }

  Future<dynamic> getSong(String videoId) async {
    try {
      await _ensureInitialized();
      return await _ytMusic.getSong(videoId);
    } catch (e) {
      print('Error getting song: $e');
      throw Exception('Failed to get song details');
    }
  }

  Future<Album> getAlbum(String albumId) async {
    try {
      await _ensureInitialized();
      final albumData = await _ytMusic.getAlbum(albumId);

      // Extract song IDs from the album tracks
      final songIds = albumData.songs
          .map((song) => song.videoId)
          .where((id) => id.isNotEmpty)
          .toList();

      return Album(
        id: albumId,
        title: albumData.name,
        artist: albumData.artist.name,
        thumbnailUrl: albumData.thumbnails.isNotEmpty
            ? albumData.thumbnails.first.url
            : '',
        songCount: albumData.songs.length,
        songIds: songIds,
      );
    } catch (e) {
      print('Error getting album: $e');
      throw Exception('Failed to get album details');
    }
  }

  Future<List<Album>> getTopAlbums() async {
    try {
      await _ensureInitialized();

      // Try to get albums through search
      try {
        final results = await _ytMusic.searchAlbums(
          'global top albums currently by verified artists',
        );
        return results
            .take(10)
            .map(
              (item) => Album(
                id: item.albumId ?? '',
                title: item.name,
                artist: item.artist.name,
                thumbnailUrl:
                    item.thumbnails.isNotEmpty ? item.thumbnails.first.url : '',
                songCount:
                    0, // Detailed song count not available in search results
                songIds: [],
              ),
            )
            .toList();
      } catch (e) {
        print('Error searching albums, falling back to home sections: $e');
      }

      // Fallback to home sections
      final homeSections = await _ytMusic.getHomeSections();
      final albumSections = homeSections
          .where(
            (section) =>
                section.title.toLowerCase().contains('album') ||
                section.title.toLowerCase().contains('new release'),
          )
          .toList();

      if (albumSections.isEmpty) {
        throw Exception('No album sections found and search failed');
      }

      // Extract albums from sections
      final albums = <Album>[];

      for (final section in albumSections) {
        for (final item in section.contents) {
          if (item.type == 'album') {
            albums.add(
              Album(
                id: item.videoId ?? '',
                title: item.name ?? 'Unknown Album',
                artist: item.artist?.name ?? 'Unknown Artist',
                thumbnailUrl: _getThumbnailUrl(item),
                songCount: 0, // Detailed count not available in home section
                songIds: [],
              ),
            );

            if (albums.length >= 10) break;
          }
        }
        if (albums.length >= 10) break;
      }

      if (albums.isEmpty) {
        throw Exception('No albums found in sections');
      }

      return albums;
    } catch (e) {
      print('Error getting top albums: $e');
      throw Exception('Failed to get top albums');
    }
  }

  void dispose() {
    _isInitialized = false;
    _youtubeExplode.close();
  }

  YoutubeExplode get youtubeExplode => _youtubeExplode;
}
