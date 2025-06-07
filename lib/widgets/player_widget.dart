import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../main.dart';
import 'package:flutter_sliding_box/flutter_sliding_box.dart';
import '../models/position_data.dart';

class PlayerWidget extends StatelessWidget {
  final BoxController controller;

  const PlayerWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, mediaSnapshot) {
        if (!mediaSnapshot.hasData) return const SizedBox.shrink();

        final mediaItem = mediaSnapshot.data!;
        final isLoading = mediaItem.extras?['isLoading'] ?? false;

        return StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,
          builder: (context, snapshot) {
            final playbackState = snapshot.data;
            final processingState = playbackState?.processingState;
            final playing = playbackState?.playing ?? false;
            final buffering = processingState == AudioProcessingState.loading ||
                processingState == AudioProcessingState.buffering;

            return SizedBox(
              height: 72,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Main content
                  Expanded(
                    child: ListTile(
                      onTap: () => controller.openBox(),
                      leading: Hero(
                        tag: 'album-art',
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            image: mediaItem.artUri != null
                                ? DecorationImage(
                                    image: NetworkImage(
                                      mediaItem.artUri.toString(),
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: mediaItem.artUri == null
                              ? Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Theme.of(context).colorScheme.primary,
                                        Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.music_note,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      title: Text(
                        mediaItem.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        mediaItem.artist ?? 'Unknown Artist',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => audioHandler.skipToPrevious(),
                            icon: const Icon(Icons.skip_previous),
                            color: Colors.white,
                          ),
                          if (buffering || isLoading)
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondary,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 20,
                                ),
                                color: Colors.white,
                                onPressed: playing
                                    ? audioHandler.pause
                                    : audioHandler.play,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          IconButton(
                            onPressed: () => audioHandler.skipToNext(),
                            icon: const Icon(Icons.skip_next),
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Progress bar
                  StreamBuilder<PositionData>(
                    stream: audioHandler.positionDataStream,
                    builder: (context, snapshot) {
                      final positionData = snapshot.data ??
                          PositionData(
                            position: Duration.zero,
                            bufferedPosition: Duration.zero,
                            duration: Duration.zero,
                          );

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 3,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            // Buffered progress
                            Container(
                              width: MediaQuery.of(context).size.width *
                                  positionData.bufferedProgress,
                              color: Colors.white.withOpacity(0.1),
                            ),
                            // Current position
                            Container(
                              width: MediaQuery.of(context).size.width *
                                  positionData.progress,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
