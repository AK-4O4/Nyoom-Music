import 'package:flutter/material.dart';
import '../../models/song_model.dart';
import '../../models/album_model.dart';
import '../../services/local_storage_service.dart';
import '../../services/youtube_music_service.dart';
import '../../widgets/song_list_tile.dart';
import '../../widgets/album_display_section_widget.dart';
import 'package:audio_service/audio_service.dart';
import '../../main.dart';
import '../../screens/playlist_screen.dart';
import '../../widgets/app_bar_widget.dart';
import '../../widgets/quick_access_button.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with AutomaticKeepAliveClientMixin {
  final LocalStorageService _storageService = LocalStorageService();
  final YoutubeMusicService _musicService = YoutubeMusicService();
  List<Song> _recentSongs = [];
  List<Song> _topSongs = [];
  List<Song> _recentlyPlayed = [];
  List<Album> _topAlbums = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load data concurrently
      final results = await Future.wait([
        _storageService.getLocalSongs(),
        _musicService.getTopSongs(),
        _storageService.loadHistory(), // Load history songs
        _musicService.getTopAlbums(),
      ]);

      if (mounted) {
        setState(() {
          _recentSongs = results[0] as List<Song>;
          _topSongs = results[1] as List<Song>;
          _recentlyPlayed = results[2] as List<Song>; // Store history songs
          _topAlbums = results[3] as List<Album>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading data: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
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
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            appBarWidget(context),
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Home',
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                  ),
                  // Quick Access Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
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
                      QuickAccessButton(
                        icon: Icons.shuffle,
                        label: 'Shuffle Play',
                        color: Colors.yellow,
                        onTap: () {
                          _shuffleAllSongs();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 35),

                  // Album Display Section
                  if (_topAlbums.isNotEmpty)
                    AlbumDisplaySectionWidget(
                      albums: _topAlbums,
                      title: 'Trending Albums',
                    ),

                  // Top Songs Section
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Top Songs',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (_topSongs.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.trending_up,
                            size: 48,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 8),
                          const Text('No top songs available'),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _topSongs.take(5).length,
                      itemBuilder: (context, index) {
                        final song = _topSongs[index];
                        final itemCount = _topSongs.take(5).length;
                        // Set position based on index
                        final position = itemCount == 1
                            ? TilePosition.single
                            : index == 0
                                ? TilePosition.first
                                : index == itemCount - 1
                                    ? TilePosition.last
                                    : TilePosition.middle;

                        return SongListTile(song: song, position: position);
                      },
                    ),

                  // Add bottom padding to make space for the mini player
                  StreamBuilder<MediaItem?>(
                    stream: audioHandler.mediaItem,
                    builder: (context, snapshot) {
                      final bool songIsPlaying = snapshot.hasData;
                      // Add extra padding at the bottom when a song is playing to make room for mini player
                      return SizedBox(height: songIsPlaying ? 80.0 : 16.0);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shuffleAllSongs() async {
    try {
      final allSongs = await _storageService.getAllOfflineSongs();
      final likedSongs = await _storageService.loadLikedSongs();

      // Combine offline and liked songs
      allSongs.addAll(
        likedSongs.where(
          (liked) => !allSongs.any((offline) => offline.id == liked.id),
        ),
      );

      if (allSongs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No songs available to play')),
          );
        }
        return;
      }

      // Shuffle the songs
      allSongs.shuffle();

      // Play the first song
      await audioHandler.playSong(allSongs.first);

      // Add the rest to the queue
      if (allSongs.length > 1) {
        final mediaItems = allSongs
            .skip(1)
            .map(
              (song) => MediaItem(
                id: song.id,
                title: song.title,
                artist: song.artist,
                artUri: song.thumbnailUrl.isNotEmpty
                    ? Uri.parse(song.thumbnailUrl)
                    : null,
                extras: {
                  'filePath': song.filePath,
                  'isOffline': song.isOffline,
                  'isLocal': song.isLocal,
                  'isDownloaded': song.isDownloaded,
                },
              ),
            )
            .toList();

        await audioHandler.updateQueue(mediaItems);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing songs: $e')),
        );
      }
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _musicService.dispose();
    super.dispose();
  }
}
