import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song_model.dart';
import '../main.dart';
import '../services/local_storage_service.dart';
import '../services/youtube_music_service.dart';
import '../services/download_service.dart';
import '../services/permission_service.dart';
import '../widgets/download_progress_bar.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

enum TilePosition {
  single, // Only one tile in the list
  first, // First tile in the list
  middle, // Middle tile in the list
  last, // Last tile in the list
}

class SongListTile extends StatefulWidget {
  final Song song;
  final VoidCallback? onTap;
  final bool showAddToQueue;
  final bool showRemoveFromQueue;
  final TilePosition position;
  final bool isInPlaylist;
  final Function(Song song)? onDownloadRequest;

  const SongListTile({
    super.key,
    required this.song,
    this.onTap,
    this.showAddToQueue = true,
    this.showRemoveFromQueue = false,
    this.position = TilePosition.middle,
    this.isInPlaylist = false,
    this.onDownloadRequest,
  });

  @override
  State<SongListTile> createState() => _SongListTileState();
}

class _SongListTileState extends State<SongListTile> {
  final LocalStorageService _storageService = LocalStorageService();
  final YoutubeMusicService _musicService = YoutubeMusicService();
  final PermissionService _permissionService = PermissionService();
  final DownloadService _downloadService = DownloadService();
  StreamSubscription? _downloadSubscription;
  bool _isLiked = false;
  bool _isDownloaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  late ScaffoldMessengerState _scaffoldMessenger;

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
    _checkIfDownloaded();
    _loadDownloadState();
    _setupDownloadListener();
  }

  @override
  void didUpdateWidget(SongListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _checkIfLiked();
      _checkIfDownloaded();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  Future<void> _checkIfLiked() async {
    final isLiked = await _storageService.isSongLiked(widget.song.id);
    if (mounted) {
      setState(() {
        _isLiked = isLiked;
        widget.song.isLiked = isLiked;
      });
    }
  }

  Future<void> _checkIfDownloaded() async {
    final isDownloaded = await _storageService.isSongDownloaded(widget.song.id);
    if (mounted) {
      setState(() {
        _isDownloaded = isDownloaded;
      });
    }
  }

  Future<void> _loadDownloadState() async {
    final progress = await _storageService.getDownloadState(widget.song.id);
    if (mounted && progress > 0 && progress < 1) {
      setState(() {
        _isDownloading = true;
        _downloadProgress = progress;
      });
    }
  }

  void _setupDownloadListener() {
    _downloadService.downloadStream.listen((info) {
      if (info.id == widget.song.id && mounted) {
        setState(() {
          _isDownloading = info.status == DownloadStatus.downloading;
          _downloadProgress = info.progress;
          if (info.status == DownloadStatus.completed) {
            _isDownloaded = true;
          }
        });
      }
    });
  }

  MediaItem _songToMediaItem(Song song) {
    return MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      artUri:
          song.thumbnailUrl.isNotEmpty ? Uri.parse(song.thumbnailUrl) : null,
      extras: {'filePath': song.filePath, 'isOffline': song.isOffline},
    );
  }

  Future<bool> _checkAndRequestPermissions() async {
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

  void _showSnackBar(String message) {
    if (!mounted) return;
    _scaffoldMessenger.clearSnackBars();
    _scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleDownload() async {
    if (!mounted) return;

    if (_isDownloaded) {
      _showSnackBar('Song is already downloaded');
      return;
    }

    if (_isDownloading) {
      _downloadService.cancelDownload(widget.song.id);
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });
      _showSnackBar('Download cancelled');
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final result = await _downloadService.startDownload(
        widget.song,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _downloadProgress = progress;
          });
          print(
              'Download progress for ${widget.song.title}: ${(progress * 100).toStringAsFixed(1)}%');
        },
        onDownloadingChanged: (downloading) {
          if (!mounted) return;
          setState(() {
            _isDownloading = downloading;
          });
          print(
              'Download status for ${widget.song.title}: ${downloading ? "Downloading" : "Not downloading"}');
        },
        onDownloadedChanged: (downloaded) {
          if (!mounted) return;
          setState(() {
            _isDownloaded = downloaded;
          });
          print(
              'Download complete for ${widget.song.title}: ${downloaded ? "Success" : "Failed"}');
        },
      );

      if (!mounted) return;

      if (result?.status == DownloadStatus.completed) {
        print('Download finished for ${widget.song.title}');
        _showSnackBar('Download completed');
      } else if (result?.status == DownloadStatus.failed) {
        print(
            'Download failed for ${widget.song.title}: ${result?.error ?? "Unknown error"}');
        _showSnackBar('Download failed: ${result?.error ?? "Unknown error"}');
      }
    } catch (e) {
      if (!mounted) return;
      print('Error downloading ${widget.song.title}: $e');
      _showSnackBar('Download failed: $e');
    }
  }

  Future<void> _toggleDownload(BuildContext context) async {
    if (!mounted) return;
    try {
      if (_isDownloaded) {
        // Remove downloaded file
        final songs = await _storageService.loadDownloadedSongs();
        final song = songs.firstWhere((s) => s.id == widget.song.id);
        if (song.filePath != null) {
          final file = File(song.filePath!);
          if (await file.exists()) {
            await file.delete();
          }
        }
        if (!mounted) return;
        setState(() {
          _isDownloaded = false;
        });
        _showSnackBar('Removed from downloads');
      } else if (_isDownloading) {
        _downloadService.cancelDownload(widget.song.id);
        if (!mounted) return;
        _showSnackBar('Download cancelled');
      } else {
        _handleDownload();
      }
    } catch (e) {
      print('Error in toggle download: $e');
      if (!mounted) return;
      _showSnackBar('Error: $e');
    }
  }

  Future<void> _moreOptions() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Song info at the top
              Container(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: widget.song.thumbnailUrl.isNotEmpty
                          ? Image.network(
                              widget.song.thumbnailUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 60,
                              height: 60,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.1),
                              child: const Icon(
                                Icons.music_note,
                                size: 30,
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),
                    // Song title and artist
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.song.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.song.artist,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Options
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('Play Song'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await audioHandler.playSong(widget.song);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error playing song: $e'),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                  }
                },
              ),
              if (widget.showAddToQueue)
                ListTile(
                  leading: const Icon(Icons.queue_music),
                  title: const Text('Add to Queue'),
                  onTap: () async {
                    Navigator.pop(context);
                    await audioHandler.addQueueItem(
                      _songToMediaItem(widget.song),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Added to queue')),
                      );
                    }
                  },
                ),
              if (widget.showRemoveFromQueue)
                ListTile(
                  leading: const Icon(Icons.remove_from_queue),
                  title: const Text('Remove from Queue'),
                  onTap: () async {
                    Navigator.pop(context);
                    await audioHandler.removeQueueItem(
                      _songToMediaItem(widget.song),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Removed from queue')),
                      );
                    }
                  },
                ),
              ListTile(
                leading: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? Colors.red : null,
                ),
                title: Text(
                  _isLiked ? 'Remove from Liked' : 'Add to Liked',
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final likedSongs = await _storageService.loadLikedSongs();
                  setState(() {
                    _isLiked = !_isLiked;
                    widget.song.isLiked = _isLiked;
                  });

                  if (!_isLiked) {
                    likedSongs.removeWhere((s) => s.id == widget.song.id);
                  } else {
                    // Prevent duplicates
                    if (!likedSongs.any((s) => s.id == widget.song.id)) {
                      likedSongs.add(widget.song);
                    }
                  }
                  await _storageService.saveLikedSongs(likedSongs);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _isLiked
                              ? 'Added to liked songs'
                              : 'Removed from liked songs',
                        ),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: Icon(
                  _isDownloaded ? Icons.download_done : Icons.download,
                  color: _isDownloaded ? Colors.green : null,
                ),
                title: Text(
                  _isDownloaded ? 'Remove from Downloads' : 'Add to Downloads',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleDownload(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: const Text('Add to Playlist'),
                onTap: () async {
                  Navigator.pop(context);
                  final playlists = await _storageService.loadPlaylists();
                  // Filter out album playlists
                  final customPlaylists =
                      playlists.where((p) => !p.isAlbum).toList();
                  if (!context.mounted) return;

                  if (customPlaylists.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'No custom playlists available. Create a playlist first.'),
                      ),
                    );
                    return;
                  }

                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Add to Playlist'),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: customPlaylists.length,
                          itemBuilder: (context, index) {
                            final playlist = customPlaylists[index];
                            final isInPlaylist = playlist.songs
                                .any((s) => s.id == widget.song.id);
                            return ListTile(
                              title: Text(playlist.name),
                              subtitle: Text('${playlist.songs.length} songs'),
                              trailing: isInPlaylist
                                  ? IconButton(
                                      icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.red),
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        final success = await _storageService
                                            .removeSongFromPlaylist(
                                          widget.song.id,
                                          playlist.id,
                                        );
                                        if (!context.mounted) return;

                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              success
                                                  ? 'Removed from ${playlist.name}'
                                                  : 'Failed to remove from ${playlist.name}',
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : null,
                              onTap: isInPlaylist
                                  ? null
                                  : () async {
                                      Navigator.pop(context);
                                      final success = await _storageService
                                          .addSongToPlaylist(
                                        widget.song,
                                        playlist.id,
                                      );
                                      if (!context.mounted) return;

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            success
                                                ? 'Added to ${playlist.name}'
                                                : 'Song already in ${playlist.name}',
                                          ),
                                        ),
                                      );
                                    },
                            );
                          },
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    final thumbnailSize = isSmallScreen ? 40.0 : 48.0;

    // Determine the border radius based on position
    BorderRadius borderRadius;
    switch (widget.position) {
      case TilePosition.single:
        borderRadius = BorderRadius.circular(12);
        break;
      case TilePosition.first:
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        );
        break;
      case TilePosition.last:
        borderRadius = const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        );
        break;
      case TilePosition.middle:
        borderRadius = BorderRadius.zero;
        break;
    }

    return Dismissible(
      key: Key(widget.song.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        await audioHandler.addQueueItem(_songToMediaItem(widget.song));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Added to queue')),
          );
        }
        return false;
      },
      background: Container(
        margin: EdgeInsets.only(
          bottom: widget.position == TilePosition.last ||
                  widget.position == TilePosition.single
              ? size.height * 0.01
              : 1,
          left: size.width * 0.02,
          right: size.width * 0.02,
          top: widget.position == TilePosition.first ||
                  widget.position == TilePosition.single
              ? size.height * 0.01
              : 0,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: borderRadius,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        child: const Icon(
          Icons.queue_music,
          color: Colors.white,
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(
              bottom: widget.position == TilePosition.last ||
                      widget.position == TilePosition.single
                  ? size.height * 0.01
                  : 1,
              left: size.width * 0.02,
              right: size.width * 0.02,
              top: widget.position == TilePosition.first ||
                      widget.position == TilePosition.single
                  ? size.height * 0.01
                  : 0,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: borderRadius,
            ),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: size.width * 0.04,
                vertical: size.height * 0.01,
              ),
              leading: Hero(
                tag: 'song-art-${widget.song.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: widget.song.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          widget.song.thumbnailUrl,
                          width: thumbnailSize,
                          height: thumbnailSize,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            width: thumbnailSize,
                            height: thumbnailSize,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            child: Icon(
                              Icons.music_note,
                              size: thumbnailSize * 0.5,
                            ),
                          ),
                        )
                      : Container(
                          width: thumbnailSize,
                          height: thumbnailSize,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          child:
                              Icon(Icons.music_note, size: thumbnailSize * 0.5),
                        ),
                ),
              ),
              title: Text(
                widget.song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
              ),
              subtitle: Text(
                widget.song.artist,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isSmallScreen ? 12 : 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () async {
                try {
                  await audioHandler.playSong(widget.song);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error playing song: $e'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                }
              },
              onLongPress: _moreOptions,
              trailing: IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: _moreOptions,
              ),
            ),
          ),
          if (_isDownloading && widget.isInPlaylist)
            DownloadProgressBar(
              progress: _downloadProgress,
              margin: EdgeInsets.symmetric(
                horizontal: size.width * 0.02,
                vertical: 4,
              ),
            ),
        ],
      ),
    );
  }
}
