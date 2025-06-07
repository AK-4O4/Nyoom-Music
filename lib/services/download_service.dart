import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song_model.dart';
import 'local_storage_service.dart';
import 'youtube_music_service.dart';
import 'storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DownloadStatus {
  notStarted,
  downloading,
  completed,
  failed,
  cancelled,
}

class DownloadInfo {
  final String id;
  final String title;
  final String artist;
  final String url;
  final String filePath;
  int totalBytes;
  int downloadedBytes;
  DownloadStatus status;
  String? error;

  DownloadInfo({
    required this.id,
    required this.title,
    required this.artist,
    required this.url,
    required this.filePath,
    required this.totalBytes,
    this.downloadedBytes = 0,
    this.status = DownloadStatus.notStarted,
    this.error,
  });

  double get progress => totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;
}

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;

  final YoutubeMusicService _musicService;
  final LocalStorageService _storageService;
  late StorageService _appStorageService;
  final Dio _dio = Dio();
  final Map<String, DownloadInfo> _downloads = {};
  final Map<String, CancelToken> _cancelTokens = {};

  Stream<DownloadInfo> get downloadStream =>
      Stream.fromIterable(_downloads.values);

  DownloadService._internal()
      : _musicService = YoutubeMusicService(),
        _storageService = LocalStorageService() {
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _appStorageService = StorageService(prefs);
  }

  Future<bool> checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        final result = await Permission.storage.request();
        return result.isGranted;
      }
      return true;
    }
    return true;
  }

  Future<String> _getDownloadPath() async {
    // First try to get the custom storage path
    final customPath = _appStorageService.getStoragePath();
    if (customPath != null) {
      final musicDir = Directory('$customPath/Music');
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }
      print('Using custom storage path: ${musicDir.path}');
      return musicDir.path;
    }

    // Fallback to default storage
    if (Platform.isAndroid) {
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final musicDir = Directory('${externalDir.path}/Music');
          if (!await musicDir.exists()) {
            await musicDir.create(recursive: true);
          }
          print('Using external storage path: ${musicDir.path}');
          return musicDir.path;
        }
      } catch (e) {
        print('Error accessing external storage: $e');
      }
    }

    final directory = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${directory.path}/Music');
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    print('Using app documents path: ${downloadsDir.path}');
    return downloadsDir.path;
  }

  Future<DownloadInfo?> startDownload(
    Song song, {
    required Function(double) onProgress,
    required Function(bool) onDownloadingChanged,
    required Function(bool) onDownloadedChanged,
  }) async {
    try {
      onDownloadingChanged(true);
      await _storageService.saveDownloadState(song.id, 0.0);

      // Get video info and stream
      final video = await _musicService.youtubeExplode.videos.get(song.id);
      if (video == null) {
        throw Exception('Could not get video information');
      }

      final manifest = await _musicService.youtubeExplode.videos.streamsClient
          .getManifest(song.id);
      final audioOnly = manifest.audioOnly;
      if (audioOnly.isEmpty) {
        throw Exception('No audio stream available');
      }

      final streamInfo = audioOnly.reduce(
          (a, b) => a.bitrate.bitsPerSecond > b.bitrate.bitsPerSecond ? a : b);

      final downloadPath = await _getDownloadPath();
      final filename =
          '${song.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}.mp3';
      final filePath = '$downloadPath/$filename';
      print('Downloading song to: $filePath');

      final downloadInfo = DownloadInfo(
        id: song.id,
        title: song.title,
        artist: song.artist,
        url: streamInfo.url.toString(),
        filePath: filePath,
        totalBytes: streamInfo.size.totalBytes,
        status: DownloadStatus.downloading,
      );

      _downloads[song.id] = downloadInfo;
      final cancelToken = CancelToken();
      _cancelTokens[song.id] = cancelToken;

      // Download audio stream
      final stream =
          _musicService.youtubeExplode.videos.streamsClient.get(streamInfo);
      final file = File(filePath);
      final fileStream = file.openWrite();
      var count = 0;

      try {
        await for (final data in stream) {
          if (cancelToken.isCancelled) {
            throw Exception('Download cancelled');
          }

          count += data.length;
          final progress = count / streamInfo.size.totalBytes;
          downloadInfo.downloadedBytes = count;
          onProgress(progress);
          await _storageService.saveDownloadState(song.id, progress);
          fileStream.add(data);
        }
        await fileStream.flush();
        await fileStream.close();

        downloadInfo.status = DownloadStatus.completed;
        onDownloadedChanged(true);
        onDownloadingChanged(false);
        await _storageService.clearDownloadState(song.id);
        _cancelTokens.remove(song.id);
        return downloadInfo;
      } catch (e) {
        if (await file.exists()) {
          await file.delete();
        }
        rethrow;
      }
    } catch (e) {
      onDownloadingChanged(false);
      await _storageService.clearDownloadState(song.id);
      if (e.toString().contains('cancelled')) {
        _downloads[song.id]?.status = DownloadStatus.cancelled;
      } else {
        _downloads[song.id]?.status = DownloadStatus.failed;
        _downloads[song.id]?.error = e.toString();
      }
      _cancelTokens.remove(song.id);
      return _downloads[song.id];
    }
  }

  void cancelDownload(String songId) {
    _cancelTokens[songId]?.cancel('Download cancelled by user');
    _cancelTokens.remove(songId);
  }

  DownloadInfo? getDownloadInfo(String songId) {
    return _downloads[songId];
  }

  bool isDownloading(String songId) {
    return _downloads[songId]?.status == DownloadStatus.downloading;
  }

  void clearCompletedDownloads() {
    _downloads.removeWhere((_, info) =>
        info.status == DownloadStatus.completed ||
        info.status == DownloadStatus.failed);
  }
}
