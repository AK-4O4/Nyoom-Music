class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  final bool isPlaying;
  final bool isBuffering;

  PositionData({
    required this.position,
    required this.bufferedPosition,
    required this.duration,
    this.isPlaying = false,
    this.isBuffering = false,
  });

  double get progress =>
      duration.inMilliseconds > 0
          ? position.inMilliseconds / duration.inMilliseconds
          : 0.0;

  double get bufferedProgress =>
      duration.inMilliseconds > 0
          ? bufferedPosition.inMilliseconds / duration.inMilliseconds
          : 0.0;
}
