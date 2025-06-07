export 'album_model.dart';

class Album {
  final String id;
  final String title;
  final String artist;
  final String thumbnailUrl;
  final int songCount;
  final List<String> songIds;

  Album({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    required this.songCount,
    required this.songIds,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'thumbnailUrl': thumbnailUrl,
      'songCount': songCount,
      'songIds': songIds,
    };
  }

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      thumbnailUrl: json['thumbnailUrl'],
      songCount: json['songCount'],
      songIds: List<String>.from(json['songIds']),
    );
  }
}
