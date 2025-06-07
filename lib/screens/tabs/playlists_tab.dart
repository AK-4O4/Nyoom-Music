import 'package:flutter/material.dart';
import '../../models/playlist_model.dart';
import '../../models/album_model.dart';
import '../../services/local_storage_service.dart';
import 'package:audio_service/audio_service.dart';
import '../../main.dart';
import '../../screens/playlist_screen.dart';
import '../../widgets/playlist_cube.dart';
import '../../widgets/app_bar_widget.dart';
import '../../widgets/quick_access_button.dart';
import '../../widgets/album_list_tile.dart';

class PlaylistsTab extends StatefulWidget {
  const PlaylistsTab({super.key});

  @override
  State<PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends State<PlaylistsTab>
    with AutomaticKeepAliveClientMixin {
  final LocalStorageService _storageService = LocalStorageService();
  List<Playlist> _playlists = [];
  bool _isLoading = true;
  String? _error;
  bool _isMultiSelectMode = false;
  Set<String> _selectedPlaylists = {};

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final playlists = await _storageService.loadPlaylists();
      if (mounted) {
        setState(() {
          _playlists = playlists;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading playlists: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _togglePlaylistSelection(String playlistId) {
    setState(() {
      if (_selectedPlaylists.contains(playlistId)) {
        _selectedPlaylists.remove(playlistId);
        if (_selectedPlaylists.isEmpty) {
          _isMultiSelectMode = false;
        }
      } else {
        _selectedPlaylists.add(playlistId);
      }
    });
  }

  Future<void> _deletePlaylists() async {
    try {
      _playlists.removeWhere(
        (playlist) => _selectedPlaylists.contains(playlist.id),
      );
      await _storageService.savePlaylists(_playlists);
      setState(() {
        _selectedPlaylists.clear();
        _isMultiSelectMode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playlists deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting playlists: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Playlists'),
        content: Text(
          'Are you sure you want to delete ${_selectedPlaylists.length} playlist(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePlaylists();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _createPlaylist(String name) async {
    if (name.trim().isEmpty) return;

    final newPlaylist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      songs: [],
      createdAt: DateTime.now(),
    );

    setState(() {
      _playlists.add(newPlaylist);
    });

    try {
      await _storageService.savePlaylists(_playlists);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving playlist: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showCreatePlaylistDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Playlist'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = textController.text;
              if (name.isNotEmpty) {
                _createPlaylist(name);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return WillPopScope(
      onWillPop: () async {
        if (_isMultiSelectMode) {
          setState(() {
            _isMultiSelectMode = false;
            _selectedPlaylists.clear();
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: _isMultiSelectMode
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _isMultiSelectMode = false;
                      _selectedPlaylists.clear();
                    });
                  },
                ),
                title: Text('${_selectedPlaylists.length} selected'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: _showDeleteConfirmationDialog,
                  ),
                ],
              )
            : null,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isMultiSelectMode) appBarWidget(context),
              const Padding(
                padding: EdgeInsets.only(left: 16, right: 16, top: 30),
                child: Text(
                  'Library',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  children: [
                    QuickAccessButton(
                      icon: Icons.favorite,
                      label: 'Liked Songs',
                      color: Colors.red,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PlaylistScreen(
                              title: 'Liked Songs',
                              type: PlaylistType.liked,
                            ),
                          ),
                        );
                      },
                    ),
                    QuickAccessButton(
                      icon: Icons.download,
                      label: 'Downloads',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PlaylistScreen(
                              title: 'Downloads',
                              type: PlaylistType.downloaded,
                            ),
                          ),
                        );
                      },
                    ),
                    QuickAccessButton(
                      icon: Icons.history,
                      label: 'History',
                      color: Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PlaylistScreen(
                              title: 'Recently Played',
                              type: PlaylistType.history,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _loadPlaylists,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _playlists.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                          // ignore: deprecated_member_use
                                        ).colorScheme.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(60),
                                      ),
                                      child: Icon(
                                        Icons.queue_music,
                                        size: 64,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'No playlists yet',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Create your first playlist',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: Colors.white70),
                                    ),
                                    const SizedBox(height: 32),
                                    FilledButton.icon(
                                      onPressed: _showCreatePlaylistDialog,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Create Playlist'),
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  const SizedBox(height: 16),
                                  FutureBuilder<List<Album>>(
                                    future: _storageService.loadSavedAlbums(),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      }

                                      final albums = snapshot.data ?? [];

                                      if (albums.isEmpty) {
                                        return const SizedBox.shrink();
                                      }

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Padding(
                                            padding: EdgeInsets.only(
                                              left: 16,
                                              right: 16,
                                            ),
                                            child: Text(
                                              "Liked Albums",
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          ListView.builder(
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            itemCount: albums.length,
                                            itemBuilder: (context, index) {
                                              final album = albums[index];
                                              final position = albums.length ==
                                                      1
                                                  ? TilePosition.single
                                                  : index == 0
                                                      ? TilePosition.first
                                                      : index ==
                                                              albums.length - 1
                                                          ? TilePosition.last
                                                          : TilePosition.middle;

                                              return AlbumListTile(
                                                album: album,
                                                position: position,
                                                isLiked: true,
                                                onLikeChanged: (liked) async {
                                                  if (!liked) {
                                                    await _storageService
                                                        .removeAlbum(
                                                      album.id,
                                                    );
                                                    setState(() {});
                                                  }
                                                },
                                              );
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  const Padding(
                                    padding: EdgeInsets.only(
                                      left: 16,
                                      right: 16,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Custom Playlists",
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(16),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: 1,
                                    ),
                                    itemCount: _playlists
                                        .where((p) => !p.isAlbum)
                                        .length,
                                    itemBuilder: (context, index) {
                                      final customPlaylists = _playlists
                                          .where((p) => !p.isAlbum)
                                          .toList();
                                      final playlist = customPlaylists[index];
                                      return PlaylistCube(
                                        playlist: playlist,
                                        isSelected: _selectedPlaylists.contains(
                                          playlist.id,
                                        ),
                                        onTap: () {
                                          if (_isMultiSelectMode) {
                                            _togglePlaylistSelection(
                                                playlist.id);
                                          } else {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    PlaylistScreen(
                                                  title: playlist.name,
                                                  type: PlaylistType.custom,
                                                  playlist: playlist,
                                                ),
                                              ),
                                            ).then((_) {
                                              _loadPlaylists();
                                            });
                                          }
                                        },
                                        onLongPress: () {
                                          setState(() {
                                            _isMultiSelectMode = true;
                                            _togglePlaylistSelection(
                                                playlist.id);
                                          });
                                        },
                                        onEdit: () {
                                          // TODO: Implement edit playlist functionality
                                          print(
                                              'Edit playlist: ${playlist.name}');
                                        },
                                        onDelete: () {
                                          _togglePlaylistSelection(playlist.id);
                                          _showDeleteConfirmationDialog();
                                        },
                                      );
                                    },
                                  ),
                                  StreamBuilder<MediaItem?>(
                                    stream: audioHandler.mediaItem,
                                    builder: (context, snapshot) {
                                      final bool songIsPlaying =
                                          snapshot.hasData;
                                      return SizedBox(
                                        height: songIsPlaying ? 80.0 : 16.0,
                                      );
                                    },
                                  ),
                                ],
                              ),
              ),
            ],
          ),
        ),
        floatingActionButton: _playlists.isNotEmpty
            ? StreamBuilder<MediaItem?>(
                stream: audioHandler.mediaItem,
                builder: (context, snapshot) {
                  final bool songIsPlaying = snapshot.hasData;

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: songIsPlaying ? 60.0 : 0.0,
                    ),
                    child: FloatingActionButton(
                      onPressed: _showCreatePlaylistDialog,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.add),
                    ),
                  );
                },
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
