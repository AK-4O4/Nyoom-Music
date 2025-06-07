import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';
import '../models/position_data.dart';
import 'youtube_music_service.dart';
import 'local_storage_service.dart';
import 'dart:async';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path/path.dart' as path;

enum RepeatMode { none, all, one }

abstract class CustomAudioHandler extends BaseAudioHandler {
  Future<void> playSong(Song song);
  Future<void> setVolume(double volume);
  Future<double> getVolume();
  Stream<PositionData> get positionDataStream;
  Future<void> clearQueue();
  Future<void> moveQueueItem(int oldIndex, int newIndex);
}

class NyooomAudioHandler extends CustomAudioHandler
    with QueueHandler, SeekHandler {
  final YoutubeMusicService _musicService = YoutubeMusicService();
  final LocalStorageService _storageService = LocalStorageService();
  AudioPlayer? _player;
  Song? _currentSong;
  final List<MediaItem> _queue = [];
  int _queueIndex = -1;
  bool _isPlaying = false;
  Timer? _progressTimer;
  bool _isLoading = false;
  final YoutubeExplode _youtubeExplode = YoutubeExplode();
  Duration? _lastPosition;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _playbackEventSubscription;
  final _positionDataController = StreamController<PositionData>.broadcast();
  bool _isShuffleEnabled = false;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;

  @override
  Stream<PositionData> get positionDataStream => _positionDataController.stream;

  // Add getters for shuffle and repeat state
  bool get isShuffleEnabled => _isShuffleEnabled;
  AudioServiceRepeatMode get repeatMode => _repeatMode;

  // Add methods to control shuffle and repeat
  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _isShuffleEnabled = shuffleMode == AudioServiceShuffleMode.all;
    if (_isShuffleEnabled) {
      // Shuffle the queue but keep the current song at the beginning
      if (_queue.isNotEmpty) {
        final currentSong = _queue[_queueIndex];
        _queue.removeAt(_queueIndex);
        _queue.shuffle();
        _queue.insert(0, currentSong);
        _queueIndex = 0;
        queue.add(_queue);
      }
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {
    _repeatMode = mode;
    switch (mode) {
      case AudioServiceRepeatMode.one:
        await _player?.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
        await _player?.setLoopMode(LoopMode.all);
        break;
      case AudioServiceRepeatMode.none:
        await _player?.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.group:
        // Handle group repeat mode if needed
        break;
    }
  }

  NyooomAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    _player = AudioPlayer();

    // Setup playback event stream
    _playbackEventSubscription = _player?.playbackEventStream.listen(
      _broadcastState,
    );

    // Setup player state stream
    _playerStateSubscription = _player?.playerStateStream.listen((state) {
      _isLoading = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      _isPlaying = state.playing;

      if (_player?.playbackEvent != null) {
        _broadcastState(_player!.playbackEvent);
      }
    });

    // Setup position stream with more frequent updates
    _positionSubscription = _player
        ?.createPositionStream(
      steps: 200,
      minPeriod: const Duration(milliseconds: 200),
      maxPeriod: const Duration(milliseconds: 200),
    )
        .listen((position) {
      _lastPosition = position;
      _updatePositionData();
      _broadcastState(_player!.playbackEvent);
    });

    // Handle completion
    _player?.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });
  }

  void _updatePositionData() {
    if (_player == null) return;

    final positionData = PositionData(
      position: _player!.position,
      bufferedPosition: _player!.bufferedPosition,
      duration: _player!.duration ?? Duration.zero,
      isPlaying: _player!.playing,
      isBuffering: _player!.processingState == ProcessingState.buffering,
    );

    _positionDataController.add(positionData);
  }

  @override
  Future<void> playSong(Song song) async {
    try {
      _currentSong = song;
      _isLoading = true;

      // Add the song to history
      await _storageService.addToHistory(song);

      // Update metadata immediately to show loading state
      mediaItem.add(song.toMediaItem());

      playbackState.add(
        PlaybackState(
          controls: [
            MediaControl.pause,
            MediaControl.skipToPrevious,
            MediaControl.skipToNext,
            MediaControl.rewind,
            MediaControl.fastForward,
          ],
          systemActions: {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
            MediaAction.skipToNext,
            MediaAction.skipToPrevious,
            MediaAction.play,
            MediaAction.pause,
            MediaAction.stop,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: AudioProcessingState.loading,
          playing: true,
          updatePosition: Duration.zero,
          bufferedPosition: Duration.zero,
          speed: 1.0,
        ),
      );

      Duration? duration;
      if (song.isOffline && song.filePath != null) {
        try {
          // Play local file
          await _player?.setFilePath(song.filePath!);
          await Future.delayed(const Duration(milliseconds: 200));
          duration = _player?.duration;

          // Extract filename for better display
          final filename = path.basename(song.filePath!);
          final title = filename.replaceAll(RegExp(r'\.(mp3|m4a|wav)$'), '');

          // Update metadata with local file info
          mediaItem.add(
            MediaItem(
              id: song.id,
              title: title,
              artist: song.artist,
              album: 'Nyooom Music',
              duration: duration,
              artUri: song.thumbnailUrl.isNotEmpty
                  ? Uri.parse(song.thumbnailUrl)
                  : null,
              displayTitle: title,
              displaySubtitle: song.artist,
              displayDescription: 'Local File',
              extras: {
                'filePath': song.filePath,
                'isOffline': true,
                'isLoading': false,
              },
            ),
          );
        } catch (e) {
          print('Error playing local file: $e');
          rethrow;
        }
      } else {
        // Stream from YouTube
        try {
          final manifest =
              await _youtubeExplode.videos.streamsClient.getManifest(song.id);
          final audioOnly = manifest.audioOnly;
          if (audioOnly.isEmpty) {
            throw Exception('No audio stream available');
          }
          final streamInfo = audioOnly.withHighestBitrate();
          await _player?.setAudioSource(
            ProgressiveAudioSource(Uri.parse(streamInfo.url.toString())),
          );

          // Wait for duration to be available
          await Future.delayed(const Duration(milliseconds: 500));
          duration = _player?.duration;

          // Update metadata with stream info
          mediaItem.add(
            MediaItem(
              id: song.id,
              title: song.title,
              artist: song.artist,
              album: 'Nyooom Music',
              duration: duration,
              artUri: song.thumbnailUrl.isNotEmpty
                  ? Uri.parse(song.thumbnailUrl)
                  : null,
              displayTitle: song.title,
              displaySubtitle: song.artist,
              displayDescription: 'Streaming',
              extras: {
                'filePath': song.filePath,
                'isOffline': false,
                'isLoading': false,
              },
            ),
          );
        } catch (e) {
          print('Error getting audio stream: $e');
          rethrow;
        }
      }

      // Start playing
      _isLoading = false;
      await _player?.play();
      _isPlaying = true;

      playbackState.add(
        playbackState.value.copyWith(
          playing: true,
          controls: [
            MediaControl.pause,
            MediaControl.skipToPrevious,
            MediaControl.skipToNext,
            MediaControl.rewind,
            MediaControl.fastForward,
          ],
          systemActions: {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
            MediaAction.skipToNext,
            MediaAction.skipToPrevious,
            MediaAction.play,
            MediaAction.pause,
            MediaAction.stop,
          },
          androidCompactActionIndices: const [0, 1, 2],
        ),
      );
    } catch (e) {
      print('Error playing song: $e');
      _isLoading = false;
      _isPlaying = false;
      playbackState.add(
        PlaybackState(
          controls: [
            MediaControl.play,
            MediaControl.skipToPrevious,
            MediaControl.skipToNext,
            MediaControl.rewind,
            MediaControl.fastForward,
          ],
          systemActions: {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
            MediaAction.skipToNext,
            MediaAction.skipToPrevious,
            MediaAction.play,
            MediaAction.pause,
            MediaAction.stop,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: AudioProcessingState.error,
          playing: false,
        ),
      );
      rethrow;
    }
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player?.playing ?? false;
    final position = _player?.position ?? Duration.zero;
    final duration = _player?.duration ?? Duration.zero;
    final buffered = event.bufferedPosition;

    playbackState.add(
      PlaybackState(
        controls: [
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToPrevious,
          MediaControl.skipToNext,
          MediaControl.rewind,
          MediaControl.fastForward,
        ],
        systemActions: {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _getProcessingState(),
        playing: playing,
        updatePosition: position,
        bufferedPosition: buffered,
        speed: _player?.speed ?? 1.0,
        queueIndex: event.currentIndex,
      ),
    );

    // Update the media item with current position
    if (_currentSong != null) {
      mediaItem.add(
        MediaItem(
          id: _currentSong!.id,
          title: _currentSong!.title,
          artist: _currentSong!.artist,
          album: 'Nyooom Music',
          duration: duration,
          artUri: _currentSong!.thumbnailUrl.isNotEmpty
              ? Uri.parse(_currentSong!.thumbnailUrl)
              : null,
          displayTitle: _currentSong!.title,
          displaySubtitle: _currentSong!.artist,
          displayDescription:
              _currentSong!.isOffline ? 'Local File' : 'Streaming',
          extras: {
            'filePath': _currentSong!.filePath,
            'isOffline': _currentSong!.isOffline,
            'isLoading': _isLoading,
            'position': position.inMilliseconds,
          },
        ),
      );
    }
  }

  AudioProcessingState _getProcessingState() {
    if (_isLoading) return AudioProcessingState.loading;
    switch (_player?.processingState) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
      default:
        throw Exception("Invalid state: ${_player?.processingState}");
    }
  }

  @override
  Future<void> pause() async {
    try {
      _lastPosition = _player?.position;
      await _player?.pause();
      _isPlaying = false;
      playbackState.add(
        playbackState.value.copyWith(
          playing: false,
          controls: [
            MediaControl.play,
            MediaControl.skipToPrevious,
            MediaControl.skipToNext,
            MediaControl.rewind,
            MediaControl.fastForward,
          ],
          systemActions: {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
            MediaAction.skipToNext,
            MediaAction.skipToPrevious,
            MediaAction.play,
            MediaAction.pause,
            MediaAction.stop,
          },
          androidCompactActionIndices: const [0, 1, 2],
        ),
      );
    } catch (e) {
      print('Error pausing: $e');
    }
  }

  @override
  Future<void> play() async {
    try {
      if (_lastPosition != null) {
        await _player?.seek(_lastPosition!);
      }
      await _player?.play();
      _isPlaying = true;
      playbackState.add(
        playbackState.value.copyWith(
          playing: true,
          controls: [
            MediaControl.pause,
            MediaControl.skipToPrevious,
            MediaControl.skipToNext,
            MediaControl.rewind,
            MediaControl.fastForward,
          ],
          systemActions: {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
            MediaAction.skipToNext,
            MediaAction.skipToPrevious,
            MediaAction.play,
            MediaAction.pause,
            MediaAction.stop,
          },
          androidCompactActionIndices: const [0, 1, 2],
        ),
      );
    } catch (e) {
      print('Error playing: $e');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    _lastPosition = position;
    await _player?.seek(position);
  }

  @override
  Future<void> stop() async {
    _lastPosition = null;
    await _player?.stop();
    await _player?.seek(Duration.zero);
    _progressTimer?.cancel();
  }

  @override
  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;

    if (_repeatMode == AudioServiceRepeatMode.one) {
      // If repeat one is enabled, just restart the current song
      await seek(Duration.zero);
      await play();
      return;
    }

    if (_queueIndex >= _queue.length - 1) {
      if (_repeatMode == AudioServiceRepeatMode.all) {
        // If repeat all is enabled, go back to the first song
        _queueIndex = 0;
      } else {
        // If no repeat, stop playback
        await stop();
        return;
      }
    } else {
      _queueIndex++;
    }

    final nextMediaItem = _queue[_queueIndex];
    final nextSong = Song(
      id: nextMediaItem.id,
      title: nextMediaItem.title,
      artist: nextMediaItem.artist ?? 'Unknown Artist',
      thumbnailUrl: nextMediaItem.artUri?.toString() ?? '',
      filePath: nextMediaItem.extras?['filePath'] ?? '',
      isOffline: nextMediaItem.extras?['isOffline'] ?? false,
    );
    await playSong(nextSong);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;

    if (_repeatMode == AudioServiceRepeatMode.one) {
      // If repeat one is enabled, just restart the current song
      await seek(Duration.zero);
      await play();
      return;
    }

    // If we're more than 3 seconds into the song, restart it
    if ((_player?.position.inSeconds ?? 0) > 3) {
      await seek(Duration.zero);
      await play();
      return;
    }

    if (_queueIndex <= 0) {
      if (_repeatMode == AudioServiceRepeatMode.all) {
        // If repeat all is enabled, go to the last song
        _queueIndex = _queue.length - 1;
      } else {
        // If no repeat, restart the current song
        await seek(Duration.zero);
        await play();
        return;
      }
    } else {
      _queueIndex--;
    }

    final prevMediaItem = _queue[_queueIndex];
    final prevSong = Song(
      id: prevMediaItem.id,
      title: prevMediaItem.title,
      artist: prevMediaItem.artist ?? 'Unknown Artist',
      thumbnailUrl: prevMediaItem.artUri?.toString() ?? '',
      filePath: prevMediaItem.extras?['filePath'] ?? '',
      isOffline: prevMediaItem.extras?['isOffline'] ?? false,
    );
    await playSong(prevSong);
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    _queue.add(mediaItem);
    queue.add(_queue);
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    _queue.remove(mediaItem);
    queue.add(_queue);
  }

  @override
  Future<void> clearQueue() async {
    _queue.clear();
    queue.add(_queue);
  }

  @override
  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    if (oldIndex < 0 ||
        oldIndex >= _queue.length ||
        newIndex < 0 ||
        newIndex >= _queue.length) {
      return;
    }
    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);
    queue.add(_queue);
  }

  Future<void> cleanUp() async {
    try {
      await _player?.dispose();
      _player = null;
    } catch (e) {
      print('Error during cleanup: $e');
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      await _player?.setVolume(volume);
    } catch (e) {
      print('Error setting volume: $e');
    }
  }

  @override
  Future<double> getVolume() async {
    try {
      return _player?.volume ?? 1.0;
    } catch (e) {
      print('Error getting volume: $e');
      return 1.0;
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _playbackEventSubscription?.cancel();
    _positionDataController.close();
    _player?.dispose();
    _musicService.dispose();
  }
}
