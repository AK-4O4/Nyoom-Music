import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:crypto/crypto.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../models/album_model.dart';

class LocalStorageService {
  final String _playlistsFile = 'playlists.json';
  final String _likedSongsFile = 'liked_songs.json';
  final String _historyFile = 'song_history.json';
  final String _downloadsFile = 'downloads.json';
  final String _downloadStateFile = 'download_state.json';
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Maximum number of songs to keep in history
  final int _maxHistoryItems = 100;

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> _getFile(String filename) async {
    final path = await _localPath;
    return File('$path/$filename');
  }

  // Generate consistent ID for offline songs
  String generateConsistentId(String filePath, String title, String artist) {
    final input = '$filePath$title$artist';
    return md5.convert(utf8.encode(input)).toString();
  }

  Future<List<Directory>> _getMusicDirectories() async {
    final List<Directory> directories = [];

    try {
      // Add device's Downloads directory
      final externalDirs = await getExternalStorageDirectories();
      if (externalDirs != null) {
        for (var dir in externalDirs) {
          String path = dir.path;
          // Navigate up to find the root storage directory
          final List<String> paths = path.split("/");
          final rootPath = paths.take(paths.indexOf("Android")).join("/");

          // Add Downloads directory
          final downloadsDir = Directory("$rootPath/Download");
          if (await downloadsDir.exists()) {
            print('Found downloads directory: ${downloadsDir.path}');
            directories.add(downloadsDir);
          }
        }
      }
    } catch (e) {
      print('Error getting music directories: $e');
    }

    return directories;
  }

  Future<Song?> _processAudioFile(File file) async {
    try {
      final String path = file.path;
      final String lowerPath = path.toLowerCase();
      if (!lowerPath.endsWith('.mp3')) return null;

      final filename = path.split('/').last;
      String title = filename.replaceAll(
        RegExp(r'\.mp3$', caseSensitive: false),
        '',
      );

      // Extract artist name if it's in the format "Title - Artist.mp3"
      String artist = 'Unknown Artist';
      if (title.contains(' - ')) {
        final parts = title.split(' - ');
        title = parts[0];
        artist = parts[1];
      }

      // Generate consistent ID for the song
      String songId = generateConsistentId(path, title, artist);

      return Song(
        id: songId,
        title: title,
        artist: artist,
        thumbnailUrl: '',
        isOffline: true,
        filePath: path,
        isLocal: true,
        isDownloaded: true,
      );
    } catch (e) {
      print('Error processing file ${file.path}: $e');
      return null;
    }
  }

  Future<List<Song>> getLocalSongs() async {
    try {
      final List<Song> localSongs = [];
      final directories = await _getMusicDirectories();

      print(
        'Scanning directories for music: ${directories.map((d) => d.path).join(", ")}',
      );

      for (var directory in directories) {
        await for (var entity in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            final song = await _processAudioFile(entity);
            if (song != null) {
              final isDownloaded = await isSongDownloaded(song.id);
              if (!isDownloaded) {
                localSongs.add(song);
              }
            }
          }
        }
      }

      print('Found ${localSongs.length} local songs');
      return localSongs;
    } catch (e) {
      print('Error getting local songs: $e');
      return [];
    }
  }

  Future<void> savePlaylists(List<Playlist> playlists) async {
    final file = await _getFile(_playlistsFile);
    final data = playlists.map((playlist) => playlist.toJson()).toList();
    await file.writeAsString(json.encode(data));
  }

  Future<List<Playlist>> loadPlaylists() async {
    try {
      final file = await _getFile(_playlistsFile);
      if (!await file.exists()) return [];

      final contents = await file.readAsString();
      final List<dynamic> data = json.decode(contents);
      return data.map((json) => Playlist.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveLikedSongs(List<Song> songs) async {
    // Remove duplicates by ID
    final Map<String, Song> uniqueSongs = {};
    for (var song in songs) {
      uniqueSongs[song.id] = song;
    }

    final file = await _getFile(_likedSongsFile);
    final data = uniqueSongs.values.map((song) => song.toJson()).toList();
    await file.writeAsString(json.encode(data));
  }

  Future<List<Song>> loadLikedSongs() async {
    try {
      final file = await _getFile(_likedSongsFile);
      if (!await file.exists()) return [];

      final contents = await file.readAsString();
      final List<dynamic> data = json.decode(contents);
      return data.map((json) => Song.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  // Check if a song is liked by its ID
  Future<bool> isSongLiked(String songId) async {
    final likedSongs = await loadLikedSongs();
    return likedSongs.any((song) => song.id == songId);
  }

  // Add a song to a playlist without creating duplicates
  Future<bool> addSongToPlaylist(Song song, String playlistId) async {
    try {
      final playlists = await loadPlaylists();
      final playlistIndex = playlists.indexWhere((p) => p.id == playlistId);

      if (playlistIndex == -1) {
        return false;
      }

      // Check if song already exists in the playlist
      if (!playlists[playlistIndex].songs.any((s) => s.id == song.id)) {
        final updatedSongs = [...playlists[playlistIndex].songs, song];
        final updatedPlaylist = Playlist(
          id: playlists[playlistIndex].id,
          name: playlists[playlistIndex].name,
          description: playlists[playlistIndex].description,
          songs: updatedSongs,
          createdAt: playlists[playlistIndex].createdAt,
          thumbnailUrl: playlists[playlistIndex].thumbnailUrl,
        );

        playlists[playlistIndex] = updatedPlaylist;
        await savePlaylists(playlists);
        return true;
      }

      return false; // Song already exists in playlist
    } catch (e) {
      print('Error adding song to playlist: $e');
      return false;
    }
  }

  // Remove song from a playlist
  Future<bool> removeSongFromPlaylist(String songId, String playlistId) async {
    try {
      final playlists = await loadPlaylists();
      final playlistIndex = playlists.indexWhere((p) => p.id == playlistId);

      if (playlistIndex == -1) {
        return false;
      }

      final updatedSongs =
          playlists[playlistIndex].songs.where((s) => s.id != songId).toList();
      final updatedPlaylist = Playlist(
        id: playlists[playlistIndex].id,
        name: playlists[playlistIndex].name,
        description: playlists[playlistIndex].description,
        songs: updatedSongs,
        createdAt: playlists[playlistIndex].createdAt,
        thumbnailUrl: playlists[playlistIndex].thumbnailUrl,
      );

      playlists[playlistIndex] = updatedPlaylist;
      await savePlaylists(playlists);
      return true;
    } catch (e) {
      print('Error removing song from playlist: $e');
      return false;
    }
  }

  Future<void> saveToMediaStore(
    String filePath,
    String title,
    String artist,
  ) async {
    final File file = File(filePath);
    if (await file.exists()) {
      final String newPath = await getApplicationDocumentsDirectory().then(
        (dir) => '${dir.path}/Music/$title.mp3',
      );
      await file.copy(newPath);
    }
  }

  Future<void> addToHistory(Song song) async {
    try {
      final historyList = await loadHistory();

      // Remove the song if it already exists in history to avoid duplicates
      historyList.removeWhere((s) => s.id == song.id);

      // Add the song to the beginning of the list
      historyList.insert(0, song);

      // Trim the list if it exceeds maximum size
      if (historyList.length > _maxHistoryItems) {
        historyList.removeRange(_maxHistoryItems, historyList.length);
      }

      await saveHistory(historyList);
    } catch (e) {
      print('Error adding song to history: $e');
    }
  }

  Future<void> saveHistory(List<Song> songs) async {
    final file = await _getFile(_historyFile);
    final data = songs.map((song) => song.toJson()).toList();
    await file.writeAsString(json.encode(data));
  }

  Future<List<Song>> loadHistory() async {
    try {
      final file = await _getFile(_historyFile);
      if (!await file.exists()) return [];

      final contents = await file.readAsString();
      final List<dynamic> data = json.decode(contents);
      return data.map((json) => Song.fromJson(json)).toList();
    } catch (e) {
      print('Error loading history: $e');
      return [];
    }
  }

  Future<void> clearHistory() async {
    try {
      final file = await _getFile(_historyFile);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error clearing history: $e');
    }
  }

  // Save album as a playlist
  Future<bool> saveAlbumAsPlaylist(
    String albumId,
    String albumTitle,
    String artist,
    String thumbnailUrl,
    List<Song> songs,
  ) async {
    try {
      final playlists = await loadPlaylists();

      // Check if album already exists as a playlist
      if (playlists.any((p) => p.id == "album_$albumId")) {
        return false; // Album already saved
      }

      // Create a new playlist from the album
      final newPlaylist = Playlist(
        id: "album_$albumId",
        name: albumTitle,
        description: "Album by $artist",
        songs: songs,
        createdAt: DateTime.now(),
        thumbnailUrl: thumbnailUrl,
        isAlbum: true,
      );

      playlists.add(newPlaylist);
      await savePlaylists(playlists);
      return true;
    } catch (e) {
      print('Error saving album as playlist: $e');
      return false;
    }
  }

  // Check if an album is saved/liked
  Future<bool> isAlbumSaved(String albumId) async {
    try {
      final playlists = await loadPlaylists();
      return playlists.any((p) => p.id == "album_$albumId");
    } catch (e) {
      print('Error checking if album is saved: $e');
      return false;
    }
  }

  // Remove saved album
  Future<bool> removeAlbum(String albumId) async {
    try {
      final playlists = await loadPlaylists();
      final filteredPlaylists =
          playlists.where((p) => p.id != "album_$albumId").toList();

      if (filteredPlaylists.length < playlists.length) {
        await savePlaylists(filteredPlaylists);
        return true;
      }
      return false; // Album wasn't found
    } catch (e) {
      print('Error removing album: $e');
      return false;
    }
  }

  Future<List<Album>> loadSavedAlbums() async {
    try {
      final playlists = await loadPlaylists();
      final albumPlaylists = playlists.where((p) => p.isAlbum).toList();

      return albumPlaylists
          .map(
            (p) => Album(
              id: p.id.replaceFirst('album_', ''),
              title: p.name,
              artist: p.description?.replaceFirst('Album by ', '') ??
                  'Unknown Artist',
              thumbnailUrl: p.thumbnailUrl ?? '',
              songCount: p.songs.length,
              songIds: p.songs.map((s) => s.id).toList(),
            ),
          )
          .toList();
    } catch (e) {
      print('Error loading saved albums: $e');
      return [];
    }
  }

  Future<List<Song>> loadDownloadedSongs() async {
    try {
      final List<Song> allSongs = [];
      final directories = await _getMusicDirectories();

      for (var directory in directories) {
        await for (var entity in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            final song = await _processAudioFile(entity);
            if (song != null) {
              allSongs.add(song);
            }
          }
        }
      }

      return allSongs;
    } catch (e) {
      print('Error loading downloaded songs: $e');
      return [];
    }
  }

  Future<bool> isSongDownloaded(String songId) async {
    try {
      final songs = await loadDownloadedSongs();
      return songs.any((song) => song.id == songId);
    } catch (e) {
      print('Error checking if song is downloaded: $e');
      return false;
    }
  }

  // Get all offline songs (both local and downloaded)
  Future<List<Song>> getAllOfflineSongs() async {
    final localSongs = await getLocalSongs();
    final downloadedSongs = await loadDownloadedSongs();

    // Combine both lists, ensuring no duplicates
    final Map<String, Song> allSongs = {};
    for (var song in localSongs) {
      allSongs[song.id] = song;
    }
    for (var song in downloadedSongs) {
      allSongs[song.id] = song;
    }

    return allSongs.values.toList();
  }

  // Save download state
  Future<void> saveDownloadState(String songId, double progress) async {
    try {
      final file = await _getFile(_downloadStateFile);
      Map<String, dynamic> states = {};

      if (await file.exists()) {
        final contents = await file.readAsString();
        try {
          states = json.decode(contents) as Map<String, dynamic>;
        } catch (e) {
          print('Error decoding download states, starting fresh: $e');
          states = {};
        }
      }

      // Convert progress to a number to ensure proper JSON encoding
      states[songId] = progress.toDouble();
      final jsonString = json.encode(states);
      await file.writeAsString(jsonString);
    } catch (e) {
      print('Error saving download state: $e');
    }
  }

  // Get download state
  Future<double> getDownloadState(String songId) async {
    try {
      final file = await _getFile(_downloadStateFile);
      if (!await file.exists()) return 0.0;

      final contents = await file.readAsString();
      final states = json.decode(contents) as Map<String, dynamic>;
      final value = states[songId];
      if (value == null) return 0.0;

      // Handle both number and string values
      if (value is num) {
        return value.toDouble();
      } else if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      print('Error getting download state: $e');
      return 0.0;
    }
  }

  // Clear download state
  Future<void> clearDownloadState(String songId) async {
    try {
      final file = await _getFile(_downloadStateFile);
      if (!await file.exists()) return;

      final contents = await file.readAsString();
      Map<String, dynamic> states;
      try {
        states = json.decode(contents) as Map<String, dynamic>;
      } catch (e) {
        print('Error decoding download states: $e');
        return;
      }

      states.remove(songId);
      await file.writeAsString(json.encode(states));
    } catch (e) {
      print('Error clearing download state: $e');
    }
  }
}
