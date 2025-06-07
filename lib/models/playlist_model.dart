import 'song_model.dart';

class Playlist {
  final String id;
  final String name;
  final String? description;
  final String? artist;
  final List<Song> songs;
  final DateTime createdAt;
  final String? thumbnailUrl;
  final bool isAlbum;

  Playlist({
    required this.id,
    required this.name,
    this.description,
    this.artist,
    required this.songs,
    required this.createdAt,
    this.thumbnailUrl,
    this.isAlbum = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'artist': artist,
      'songs': songs.map((song) => song.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'thumbnailUrl': thumbnailUrl,
      'isAlbum': isAlbum,
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      artist: json['artist'] as String?,
      songs: (json['songs'] as List)
          .map((songJson) => Song.fromJson(songJson))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      thumbnailUrl: json['thumbnailUrl'],
      isAlbum: json['isAlbum'] ?? false,
    );
  }
}
