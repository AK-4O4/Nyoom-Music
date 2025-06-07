import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../models/album_model.dart';
import '../widgets/song_list_tile.dart';
import '../widgets/playlist_header.dart';
import '../services/local_storage_service.dart';
import '../main.dart';
import '../services/youtube_music_service.dart';
import '../widgets/player_widget.dart';
import '../widgets/expanded_player_widget.dart';
import 'package:flutter_sliding_box/flutter_sliding_box.dart';
import '../services/download_service.dart';
import '../services/permission_service.dart';

enum PlaylistType { custom, liked, downloaded, history }

class PlaylistScreen extends StatefulWidget {
  final String title;
  final PlaylistType type;
  final Playlist? playlist; // Only for custom playlists
  final String? albumId; // For album view

  const PlaylistScreen({
    super.key,
    required this.title,
    required this.type,
    this.playlist,
    this.albumId,
  });

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final LocalStorageService _storageService = LocalStorageService();
  final YoutubeMusicService _musicService = YoutubeMusicService();
  final BoxController _boxController = BoxController();
  final DownloadService _downloadService = DownloadService();
  List<Song> _songs = [];
  List<Song> _filteredSongs = [];
  bool _isLoading = true;
  String? _error;
  bool _isAlbumSaved = false;
  Album? _album;
  bool _isExpanded = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSongs();
    if (widget.albumId != null) {
      _checkIfAlbumIsSaved();
    }
  }

  @override
  void dispose() {
    _boxController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkIfAlbumIsSaved() async {
    if (widget.albumId != null) {
      final isSaved = await _storageService.isAlbumSaved(widget.albumId!);
      if (mounted) {
        setState(() {
          _isAlbumSaved = isSaved;
        });
      }
    }
  }

  Future<void> _toggleAlbumSave() async {
    if (widget.albumId == null || _album == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      bool success;
      if (_isAlbumSaved) {
        success = await _storageService.removeAlbum(widget.albumId!);
      } else {
        success = await _storageService.saveAlbumAsPlaylist(
          widget.albumId!,
          widget.title,
          _album!.artist,
          _album!.thumbnailUrl,
          _songs,
        );
      }

      if (!mounted) return;
      setState(() {
        _isAlbumSaved = !_isAlbumSaved;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isAlbumSaved
                ? 'Album added to your library'
                : 'Album removed from your library',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _loadSongs() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      List<Song> songs = [];

      // Special case for album
      if (widget.albumId != null) {
        try {
          final album = await _musicService.getAlbum(widget.albumId!);
          if (!mounted) return;

          setState(() {
            _album = album;
          });

          final songFutures = <Future<Song>>[];
          for (final songId in album.songIds) {
            songFutures.add(
              _musicService.getSong(songId).then((songData) {
                return Song(
                  id: songId,
                  title: songData.name,
                  artist: songData.artist.name,
                  thumbnailUrl: songData.thumbnails.isNotEmpty
                      ? songData.thumbnails.first.url
                      : '',
                  isOffline: false,
                  filePath: null,
                );
              }).catchError((e) {
                print('Error loading song $songId: $e');
                return Song(
                  id: songId,
                  title: 'Unknown Song',
                  artist: 'Unknown Artist',
                  thumbnailUrl: '',
                  isOffline: false,
                  filePath: null,
                );
              }),
            );
          }

          songs = await Future.wait(songFutures);
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _error = 'Error loading album: $e';
          });
          return;
        }
      } else {
        // Regular playlist handling
        try {
          switch (widget.type) {
            case PlaylistType.custom:
              if (widget.playlist != null) {
                songs = widget.playlist!.songs;
              }
              break;
            case PlaylistType.liked:
              songs = await _storageService.loadLikedSongs();
              break;
            case PlaylistType.downloaded:
              songs = await _storageService.loadDownloadedSongs();
              break;
            case PlaylistType.history:
              songs = await _storageService.loadHistory();
              break;
          }
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _error = 'Error loading playlist: $e';
          });
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        _songs = songs;
        _filteredSongs = songs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unexpected error: $e';
        _isLoading = false;
      });
    }
  }

  void _filterSongs(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSongs = _songs;
      } else {
        _filteredSongs = _songs.where((song) {
          final titleLower = song.title.toLowerCase();
          final artistLower = song.artist.toLowerCase();
          final searchLower = query.toLowerCase();
          return titleLower.contains(searchLower) ||
              artistLower.contains(searchLower);
        }).toList();
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredSongs = _songs;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colorScheme.error),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadSongs,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : CustomScrollView(
                        slivers: [
                          SliverAppBar(
                            backgroundColor:
                                Theme.of(context).appBarTheme.backgroundColor,
                            surfaceTintColor: Colors.transparent,
                            elevation: 0,
                            floating: true,
                            snap: true,
                            leading: IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            actions: [
                              IconButton(
                                onPressed: _toggleSearch,
                                icon: Icon(
                                    _isSearching ? Icons.close : Icons.search),
                              ),
                              // if (widget.type != PlaylistType.downloaded &&
                              //     widget.type != PlaylistType.history)
                              //   IconButton(
                              //     icon: const Icon(Icons.download),
                              //     onPressed: () {},
                              //   ),
                              if (widget.albumId == null)
                                IconButton(
                                  icon: const Icon(Icons.more_vert),
                                  onPressed: () {
                                    _showPlaylistOptions(context);
                                  },
                                ),
                            ],
                          ),
                          if (_isSearching)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search in ${widget.title}',
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  onChanged: _filterSongs,
                                ),
                              ),
                            ),
                          SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                _buildPlaylistHeader(context),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (widget.albumId != null)
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              _isAlbumSaved
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color: _isAlbumSaved
                                                  ? Colors.red
                                                  : null,
                                            ),
                                            onPressed: _toggleAlbumSave,
                                            tooltip: _isAlbumSaved
                                                ? 'Remove from Library'
                                                : 'Add to Library',
                                          ),
                                        ],
                                      ),
                                    if (widget.type != PlaylistType.history)
                                      PopupMenuButton(
                                        icon: const Icon(Icons.sort),
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                            child: const Row(
                                              children: [
                                                Icon(Icons.sort_by_alpha),
                                                SizedBox(width: 8),
                                                Text('Sort by Title'),
                                              ],
                                            ),
                                            onTap: () {
                                              setState(() {
                                                _songs.sort(
                                                  (a, b) => a.title
                                                      .compareTo(b.title),
                                                );
                                                _filteredSongs = _songs;
                                              });
                                            },
                                          ),
                                          PopupMenuItem(
                                            child: const Row(
                                              children: [
                                                Icon(Icons.person),
                                                SizedBox(width: 8),
                                                Text('Sort by Artist'),
                                              ],
                                            ),
                                            onTap: () {
                                              setState(() {
                                                _songs.sort(
                                                  (a, b) => a.artist.compareTo(
                                                    b.artist,
                                                  ),
                                                );
                                                _filteredSongs = _songs;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.play_arrow),
                                      onPressed: _songs.isEmpty
                                          ? null
                                          : () {
                                              _playAllSongs();
                                            },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.shuffle),
                                      onPressed: _songs.isEmpty
                                          ? null
                                          : () {
                                              _shufflePlaySongs();
                                            },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                (_isSearching ? _filteredSongs : _songs).isEmpty
                                    ? _buildEmptyState(context)
                                    : Column(
                                        children: (_isSearching
                                                ? _filteredSongs
                                                : _songs)
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          final index = entry.key;
                                          final song = entry.value;
                                          final itemCount = (_isSearching
                                                  ? _filteredSongs
                                                  : _songs)
                                              .length;
                                          final position = itemCount == 1
                                              ? TilePosition.single
                                              : index == 0
                                                  ? TilePosition.first
                                                  : index == itemCount - 1
                                                      ? TilePosition.last
                                                      : TilePosition.middle;

                                          return SongListTile(
                                            song: song,
                                            position: position,
                                            isInPlaylist: widget.playlist?.id ==
                                                'downloads',
                                            onDownloadRequest:
                                                _handleDownloadRequest,
                                          );
                                        }).toList(),
                                      ),
                                StreamBuilder<MediaItem?>(
                                  stream: audioHandler.mediaItem,
                                  builder: (context, snapshot) {
                                    final bool songIsPlaying = snapshot.hasData;
                                    return SizedBox(
                                      height: songIsPlaying ? 116.0 : 16.0,
                                    );
                                  },
                                ),
                              ]),
                            ),
                          ),
                        ],
                      ),
            StreamBuilder<MediaItem?>(
              stream: audioHandler.mediaItem,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                return SlidingBox(
                  controller: _boxController,
                  minHeight: 70,
                  maxHeight: MediaQuery.of(context).size.height * 0.99,
                  color: Theme.of(context).colorScheme.surface,
                  body: ExpandedPlayerWidget(
                    onMinimize: () => _boxController.closeBox(),
                    onShuffleChanged: (enabled) {},
                    onRepeatModeChanged: (mode) {},
                    onVolumeChanged: (volume) {},
                  ),
                  draggableIconVisible: false,
                  collapsed: true,
                  collapsedBody: PlayerWidget(controller: _boxController),
                  onBoxSlide: (position) {
                    final isExpanded = position > 0.5;
                    if (isExpanded != _isExpanded) {
                      setState(() {
                        _isExpanded = isExpanded;
                      });
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    IconData iconData;
    Color iconColor;
    String? imageUrl;
    String? artist;

    // Special case for album
    if (widget.albumId != null) {
      iconData = Icons.album;
      iconColor = colorScheme.primary;
      imageUrl = _album?.thumbnailUrl;
      artist = _album?.artist;
    } else {
      switch (widget.type) {
        case PlaylistType.custom:
          iconData = Icons.queue_music;
          iconColor = colorScheme.primary;
          imageUrl = widget.playlist?.thumbnailUrl;
          artist = widget.playlist?.artist;
          break;
        case PlaylistType.liked:
          iconData = Icons.favorite;
          iconColor = Colors.red;
          break;
        case PlaylistType.downloaded:
          iconData = Icons.download_done;
          iconColor = Colors.blue;
          break;
        case PlaylistType.history:
          iconData = Icons.history;
          iconColor = Colors.green;
          break;
      }
    }

    return PlaylistHeader(
      title: widget.title,
      songsCount: _songs.length,
      icon: iconData,
      iconColor: iconColor,
      imageUrl: imageUrl,
      artist: artist,
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String message;
    IconData iconData;

    // Special case for album
    if (widget.albumId != null) {
      message = 'No songs in this album';
      iconData = Icons.album;
    } else {
      switch (widget.type) {
        case PlaylistType.custom:
          message = 'This playlist is empty';
          iconData = Icons.queue_music;
          break;
        case PlaylistType.liked:
          message = 'No liked songs yet';
          iconData = Icons.favorite_border;
          break;
        case PlaylistType.downloaded:
          message = 'No downloaded songs';
          iconData = Icons.download_for_offline;
          break;
        case PlaylistType.history:
          message = 'No listening history yet';
          iconData = Icons.history;
          break;
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(iconData, size: 80, color: colorScheme.primary.withOpacity(0.5)),
          const SizedBox(height: 24),
          Text(
            message,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _getEmptyStateHint(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  String _getEmptyStateHint() {
    // Special case for album
    if (widget.albumId != null) {
      return 'Try searching for another album';
    }

    switch (widget.type) {
      case PlaylistType.custom:
        return 'Add songs to this playlist';
      case PlaylistType.liked:
        return 'Tap the heart icon on songs to add them here';
      case PlaylistType.downloaded:
        return 'Download songs to listen offline';
      case PlaylistType.history:
        return 'Play songs to see your listening history';
    }
  }

  void _showPlaylistOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.3,
        maxChildSize: 0.6,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(onPressed: () {}, icon: Icon(Icons.close)),
              ],
            ),
            if (widget.type == PlaylistType.custom)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Playlist'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement edit playlist
                },
              ),
            if (widget.type == PlaylistType.custom)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Playlist',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeletePlaylist(context);
                },
              ),
            if (widget.type == PlaylistType.history)
              ListTile(
                leading: const Icon(
                  Icons.delete_sweep,
                  color: Colors.red,
                ),
                title: const Text(
                  'Clear History',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmClearHistory(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePlaylist(BuildContext context) {
    if (widget.type != PlaylistType.custom || widget.playlist == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Playlist'),
        content: Text('Are you sure you want to delete "${widget.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();

              final playlists = await _storageService.loadPlaylists();
              playlists.removeWhere((p) => p.id == widget.playlist!.id);
              await _storageService.savePlaylists(playlists);

              if (mounted) {
                Navigator.of(context).pop(); // Go back to playlists screen
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
          'Are you sure you want to clear your listening history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();

              await _storageService.clearHistory();

              if (mounted) {
                setState(() {
                  _songs = [];
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('History cleared')),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _playAllSongs() async {
    if (_songs.isEmpty) return;

    try {
      await audioHandler.playSong(_songs.first);
      if (_songs.length > 1) {
        final mediaItems =
            _songs.skip(1).map((song) => _songToMediaItem(song)).toList();
        await audioHandler.updateQueue(mediaItems);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing songs: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _shufflePlaySongs() async {
    if (_songs.isEmpty) return;

    try {
      final shuffledSongs = List<Song>.from(_songs)..shuffle();
      await audioHandler.playSong(shuffledSongs.first);
      if (shuffledSongs.length > 1) {
        final mediaItems = shuffledSongs
            .skip(1)
            .map((song) => _songToMediaItem(song))
            .toList();
        await audioHandler.updateQueue(mediaItems);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing songs: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
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

  Future<void> _handleDownloadRequest(Song song) async {
    try {
      // Check permissions first
      final permissionService = PermissionService();
      final hasPermission =
          await permissionService.checkAndRequestStoragePermission();

      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to download songs'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Initiate download using the DownloadService
      _downloadService.startDownload(
        song,
        onProgress: (progress) {
          // Handle progress updates (optional, could update UI if needed)
          print(
              'Download progress for ${song.title}: ${(progress * 100).toStringAsFixed(2)}%');
        },
        onDownloadingChanged: (isDownloading) {
          // Handle downloading state change (optional)
        },
        onDownloadedChanged: (isDownloaded) {
          // Handle downloaded state change (optional, SongListTile will update)
          if (isDownloaded &&
              widget.type == PlaylistType.downloaded &&
              mounted) {
            // If the current screen is the Downloads playlist, refresh it
            _loadSongs();
          }
        },
      );

      // Show a snackbar indicating download started
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading ${song.title}...'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error initiating download: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
