import 'package:audio_service/audio_service.dart';

class Song {
  final String id;
  final String title;
  final String artist;
  final String thumbnailUrl;
  final String? duration;
  final bool isOffline;
  final String? filePath;
  final String? youtubeUrl;
  bool isLiked;
  Duration position;
  final bool isLocal;
  final bool isDownloaded;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    this.duration,
    required this.isOffline,
    this.filePath,
    this.youtubeUrl,
    this.isLiked = false,
    this.position = Duration.zero,
    this.isLocal = false,
    this.isDownloaded = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'isOffline': isOffline,
      'filePath': filePath,
      'youtubeUrl': youtubeUrl,
      'isLiked': isLiked,
      'position': position.inMilliseconds,
      'isLocal': isLocal,
      'isDownloaded': isDownloaded,
    };
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      thumbnailUrl: json['thumbnailUrl'],
      duration: json['duration'],
      isOffline: json['isOffline'],
      filePath: json['filePath'],
      youtubeUrl: json['youtubeUrl'],
      isLiked: json['isLiked'] ?? false,
      position: Duration(milliseconds: json['position'] ?? 0),
      isLocal: json['isLocal'] ?? false,
      isDownloaded: json['isDownloaded'] ?? false,
    );
  }

  MediaItem toMediaItem() {
    return MediaItem(
      id: id,
      title: title,
      artist: artist,
      album: 'Nyooom Music',
      artUri: thumbnailUrl.isNotEmpty ? Uri.parse(thumbnailUrl) : null,
      displayTitle: title,
      displaySubtitle: artist,
      displayDescription: isOffline ? 'Local File' : 'Streaming',
      extras: {
        'filePath': filePath,
        'isOffline': isOffline,
        'isLoading': false,
      },
    );
  }
}
