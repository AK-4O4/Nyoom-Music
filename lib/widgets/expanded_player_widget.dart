import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/volume_service.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import '../services/youtube_music_service.dart';
import '../services/local_storage_service.dart';
import '../models/song_model.dart';
import '../widgets/queue_display_widget.dart';

enum RepeatMode { none, all, one }

class ExpandedPlayerWidget extends StatefulWidget {
  final VoidCallback onMinimize;
  final Function(bool) onShuffleChanged;
  final Function(RepeatMode) onRepeatModeChanged;
  final Function(double) onVolumeChanged;

  const ExpandedPlayerWidget({
    super.key,
    required this.onMinimize,
    required this.onShuffleChanged,
    required this.onRepeatModeChanged,
    required this.onVolumeChanged,
  });

  @override
  State<ExpandedPlayerWidget> createState() => _ExpandedPlayerWidgetState();
}

class _ExpandedPlayerWidgetState extends State<ExpandedPlayerWidget> {
  bool _isNavigationBarVisible = true;
  double _dragStartY = 0;
  bool _isShuffle = false;
  RepeatMode _repeatMode = RepeatMode.none;
  double _volume = 1.0;
  bool _isFavorite = false;
  bool _showingLyrics = false;
  String? _lyrics;
  final _prefs = SharedPreferences.getInstance();
  final _musicService = YoutubeMusicService();
  final LocalStorageService _storageService = LocalStorageService();

  @override
  void initState() {
    super.initState();
    _initializeVolume();
    _loadSettings();
    // Listen to system volume changes
    FlutterVolumeController.addListener((volume) {
      if (mounted) {
        setState(() {
          _volume = volume;
        });
      }
    });
  }

  @override
  void dispose() {
    FlutterVolumeController.removeListener();
    VolumeService.dispose();
    super.dispose();
  }

  Future<void> _initializeVolume() async {
    try {
      final volume = await VolumeService.getVolume();
      if (mounted) {
        setState(() {
          _volume = volume;
        });
      }
      await audioHandler.setVolume(volume);
    } catch (e) {
      print('Error initializing volume: $e');
      // Set a default volume if there's an error
      _volume = 1.0;
      await audioHandler.setVolume(_volume);
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await _prefs;
    setState(() {
      _isShuffle = prefs.getBool('shuffle') ?? false;
      _repeatMode = RepeatMode.values[prefs.getInt('repeatMode') ?? 0];
      _volume = prefs.getDouble('volume') ?? 1.0;
    });

    // Check if the current song is liked
    if (audioHandler.mediaItem.value?.id != null) {
      _checkIfLiked(audioHandler.mediaItem.value!.id);
    }
  }

  Future<void> _checkIfLiked(String songId) async {
    final isLiked = await _storageService.isSongLiked(songId);
    if (mounted) {
      setState(() {
        _isFavorite = isLiked;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await _prefs;
    await prefs.setBool('shuffle', _isShuffle);
    await prefs.setInt('repeatMode', _repeatMode.index);
    await prefs.setDouble('volume', _volume);
  }

  Future<void> _updateVolume(double newVolume) async {
    if (!mounted) return;
    setState(() {
      _volume = newVolume;
    });
    await VolumeService.setVolume(newVolume);
    await audioHandler.setVolume(newVolume);
    widget.onVolumeChanged(newVolume);
    await _saveSettings();
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  void _handleDragStart(DragStartDetails details) {
    _dragStartY = details.globalPosition.dy;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    double dragDistance = details.globalPosition.dy - _dragStartY;

    if (dragDistance < -50 && _isNavigationBarVisible) {
      setState(() {
        _isNavigationBarVisible = false;
      });
    } else if (dragDistance > 50 && !_isNavigationBarVisible) {
      setState(() {
        _isNavigationBarVisible = true;
      });
    }

    // If dragging down more than 100 pixels, minimize the player
    if (dragDistance > 100) {
      widget.onMinimize();
    }
  }

  void _toggleShuffle() {
    setState(() {
      _isShuffle = !_isShuffle;
      audioHandler.setShuffleMode(
        _isShuffle ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
      );
      widget.onShuffleChanged(_isShuffle);
      _saveSettings();
    });
  }

  void _cycleRepeatMode() {
    setState(() {
      AudioServiceRepeatMode newMode;
      switch (_repeatMode) {
        case RepeatMode.none:
          newMode = AudioServiceRepeatMode.all;
          _repeatMode = RepeatMode.all;
          break;
        case RepeatMode.all:
          newMode = AudioServiceRepeatMode.one;
          _repeatMode = RepeatMode.one;
          break;
        case RepeatMode.one:
          newMode = AudioServiceRepeatMode.none;
          _repeatMode = RepeatMode.none;
          break;
      }
      audioHandler.setRepeatMode(newMode);
      widget.onRepeatModeChanged(_repeatMode);
      _saveSettings();
    });
  }

  Future<void> _toggleFavorite() async {
    if (audioHandler.mediaItem.value == null) return;

    final songId = audioHandler.mediaItem.value!.id;
    final likedSongs = await _storageService.loadLikedSongs();

    setState(() {
      _isFavorite = !_isFavorite;
    });

    if (!_isFavorite) {
      // Remove from liked songs
      likedSongs.removeWhere((s) => s.id == songId);
    } else {
      // Add to liked songs if not already there
      if (!likedSongs.any((s) => s.id == songId)) {
        // Create Song object from MediaItem
        final mediaItem = audioHandler.mediaItem.value!;
        final song = Song(
          id: mediaItem.id,
          title: mediaItem.title,
          artist: mediaItem.artist ?? 'Unknown Artist',
          thumbnailUrl: mediaItem.artUri?.toString() ?? '',
          filePath: mediaItem.extras?['filePath'] ?? '',
          isOffline: mediaItem.extras?['isOffline'] ?? false,
          isLiked: true,
        );
        likedSongs.add(song);
      }
    }

    await _storageService.saveLikedSongs(likedSongs);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorite ? 'Added to liked songs' : 'Removed from liked songs',
          ),
        ),
      );
    }
  }

  Future<void> _toggleLyrics(BuildContext context, String songId) async {
    if (_showingLyrics && _lyrics != null) {
      setState(() {
        _showingLyrics = false;
      });
      return;
    }

    setState(() {
      _showingLyrics = true;
    });

    try {
      final lyrics = await _musicService.getLyrics(songId);
      if (mounted) {
        if (lyrics == null || lyrics.isEmpty) {
          setState(() {
            _showingLyrics = false;
          });
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('No Lyrics'),
                content: const Text('No lyrics found for this song.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          }
        } else {
          setState(() {
            _lyrics = lyrics;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _showingLyrics = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load lyrics: $e')));
      }
    }
  }

  Widget _buildArtworkOrLyrics(MediaItem mediaItem) {
    if (_showingLyrics) {
      return Container(
        height: 300,
        width: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: _lyrics == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _lyrics ?? '',
                  style: const TextStyle(fontSize: 16, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
      );
    }

    return Container(
      height: 300,
      width: 300,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: mediaItem.artUri != null
            ? Image.network(
                mediaItem.artUri.toString(),
                fit: BoxFit.cover,
                cacheWidth: 600, // Higher resolution cache
                cacheHeight: 600,
                headers: const {
                  'User-Agent': 'Mozilla/5.0', // Help prevent image blocking
                },
                errorBuilder: (context, error, stackTrace) {
                  return _buildFallbackArtwork(context);
                },
              )
            : _buildFallbackArtwork(context),
      ),
    );
  }

  Widget _buildFallbackArtwork(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primary,
      child: Icon(
        Icons.music_note,
        size: 80,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        widget.onMinimize();
        return false;
      },
      child: GestureDetector(
        onVerticalDragStart: _handleDragStart,
        onVerticalDragUpdate: _handleDragUpdate,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: StreamBuilder<MediaItem?>(
              stream: audioHandler.mediaItem,
              builder: (context, mediaSnapshot) {
                if (!mediaSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final mediaItem = mediaSnapshot.data!;

                // Check if the current song is liked whenever the media item changes
                if (mediaItem.id.isNotEmpty) {
                  _checkIfLiked(mediaItem.id);
                }

                return StreamBuilder<PlaybackState>(
                  stream: audioHandler.playbackState,
                  builder: (context, playbackSnapshot) {
                    final playbackState = playbackSnapshot.data;
                    final playing = playbackState?.playing ?? false;
                    final processingState = playbackState?.processingState;
                    final position = playbackState?.position ?? Duration.zero;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const SizedBox(height: 15),
                        // Header with minimize button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: widget.onMinimize,
                              icon: const Icon(Icons.keyboard_arrow_down),
                            ),
                            Text(
                              'Now Playing',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            IconButton(
                              onPressed: () {
                                // TODO: Share song playing
                              },
                              icon: const Icon(Icons.share),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        // Album Art and Title Section
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () => _toggleLyrics(context, mediaItem.id),
                              child: _buildArtworkOrLyrics(mediaItem),
                            ),
                            const SizedBox(height: 30),
                            Text(
                              mediaItem.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 15),
                            Text(
                              mediaItem.artist ?? 'Unknown Artist',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                        // Progress Bar //TODO
                        Column(
                          children: [
                            if (mediaItem.duration != null) ...[
                              StreamBuilder<PlaybackState>(
                                stream: audioHandler.playbackState,
                                builder: (context, playbackSnapshot) {
                                  final processingState =
                                      playbackSnapshot.data?.processingState;
                                  final buffering = processingState ==
                                          AudioProcessingState.loading ||
                                      processingState ==
                                          AudioProcessingState.buffering;
                                  final position =
                                      playbackSnapshot.data?.position ??
                                          Duration.zero;
                                  final duration =
                                      mediaItem.duration ?? Duration.zero;

                                  return Column(
                                    children: [
                                      SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 4.0,
                                          activeTrackColor: buffering
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.5)
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                          inactiveTrackColor: buffering
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.1)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.3),
                                          thumbColor: buffering
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.5)
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                        ),
                                        child: Slider(
                                          value: buffering
                                              ? 0
                                              : position.inMilliseconds
                                                  .toDouble()
                                                  .clamp(
                                                    0,
                                                    duration.inMilliseconds
                                                        .toDouble(),
                                                  ),
                                          min: 0.0,
                                          max: duration.inMilliseconds
                                              .toDouble(),
                                          onChanged: buffering
                                              ? null
                                              : (value) {
                                                  audioHandler.seek(
                                                    Duration(
                                                      milliseconds:
                                                          value.toInt(),
                                                    ),
                                                  );
                                                },
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20.0,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              buffering
                                                  ? '--:--'
                                                  : _formatDuration(position),
                                            ),
                                            Text(_formatDuration(duration)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                        // Playback Controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.shuffle,
                                color: _isShuffle
                                    ? Theme.of(context).colorScheme.tertiary
                                    : null,
                              ),
                              onPressed: _toggleShuffle,
                            ),
                            IconButton(
                              icon: const Icon(Icons.skip_previous),
                              onPressed: audioHandler.skipToPrevious,
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  playing ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                ),
                                iconSize: 48,
                                onPressed: () {
                                  if (playing) {
                                    audioHandler.pause();
                                  } else {
                                    audioHandler.play();
                                  }
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.skip_next),
                              onPressed: audioHandler.skipToNext,
                            ),
                            IconButton(
                              icon: Icon(
                                _repeatMode == RepeatMode.none
                                    ? Icons.repeat
                                    : _repeatMode == RepeatMode.one
                                        ? Icons.repeat_one
                                        : Icons.repeat,
                                color: _repeatMode != RepeatMode.none
                                    ? Theme.of(context).colorScheme.tertiary
                                    : null,
                              ),
                              onPressed: _cycleRepeatMode,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Volume Control
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.volume_down),
                                onPressed: () async {
                                  await VolumeService.decreaseVolume(0.1);
                                  final newVolume =
                                      await VolumeService.getVolume();
                                  await _updateVolume(newVolume);
                                },
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor:
                                        Theme.of(context).colorScheme.primary,
                                    inactiveTrackColor: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.3),
                                    thumbColor:
                                        Theme.of(context).colorScheme.primary,
                                    trackHeight: 2.0,
                                  ),
                                  child: Slider(
                                    value: _volume,
                                    min: 0.0,
                                    max: 1.0,
                                    divisions: 20, // For more precise control
                                    onChangeStart: (value) async {
                                      // Get the current system volume when user starts dragging
                                      final currentVolume =
                                          await VolumeService.getVolume();
                                      setState(() {
                                        _volume = currentVolume;
                                      });
                                    },
                                    onChanged: (value) async {
                                      // Update UI immediately for smooth sliding
                                      setState(() {
                                        _volume = value;
                                      });
                                      // Update system and player volume
                                      await VolumeService.setVolume(value);
                                      await audioHandler.setVolume(value);
                                    },
                                    onChangeEnd: (value) async {
                                      // Save final volume and ensure everything is in sync
                                      await _updateVolume(value);
                                    },
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.volume_up),
                                onPressed: () async {
                                  await VolumeService.increaseVolume(0.1);
                                  final newVolume =
                                      await VolumeService.getVolume();
                                  await _updateVolume(newVolume);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        // Additional Controls
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                onPressed: _toggleFavorite,
                                icon: Icon(
                                  _isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: _isFavorite ? Colors.red : null,
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    _toggleLyrics(context, mediaItem.id),
                                icon: Icon(
                                  _showingLyrics
                                      ? Icons.lyrics
                                      : Icons.lyrics_outlined,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  // TODO: Show sleep timer dialog
                                },
                                icon: const Icon(Icons.bedtime),
                              ),
                              IconButton(
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) =>
                                        const QueueDisplayWidget(),
                                  );
                                },
                                icon: const Icon(Icons.queue_music),
                              ),
                              IconButton(
                                onPressed: () {
                                  // TODO: Show more options menu
                                },
                                icon: const Icon(Icons.more_horiz),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
