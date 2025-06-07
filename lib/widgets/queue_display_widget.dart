import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../main.dart';
import '../models/song_model.dart';
import 'song_list_tile.dart';

class QueueDisplayWidget extends StatelessWidget {
  const QueueDisplayWidget({super.key});

  Song _mediaItemToSong(MediaItem item) {
    return Song(
      id: item.id,
      title: item.title,
      artist: item.artist ?? 'Unknown Artist',
      thumbnailUrl: item.artUri?.toString() ?? '',
      filePath: item.extras?['filePath'] ?? '',
      isOffline: item.extras?['isOffline'] ?? false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Title and Clear All button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Queue',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.clear_all, color: Colors.white),
                  onPressed: () async {
                    // Show confirmation dialog
                    final shouldClear = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            backgroundColor: const Color.fromARGB(
                              255,
                              42,
                              41,
                              46,
                            ),
                            title: const Text(
                              'Clear Queue',
                              style: TextStyle(color: Colors.white),
                            ),
                            content: const Text(
                              'Are you sure you want to clear the entire queue?',
                              style: TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  'Clear',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                    );

                    if (shouldClear == true && context.mounted) {
                      await audioHandler.clearQueue();
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24),
          // Now Playing Section
          StreamBuilder<MediaItem?>(
            stream: audioHandler.mediaItem,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();

              final currentSong = _mediaItemToSong(snapshot.data!);
              return Container(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Now Playing',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: SongListTile(
                            song: currentSong,
                            position: TilePosition.single,
                            showAddToQueue: false,
                            showRemoveFromQueue: false,
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            await audioHandler.skipToNext();
                          },
                          icon: const Icon(
                            Icons.skip_next,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(color: Colors.white24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(left: 16),
                child: Text(
                  'Up Next',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ],
          ),
          // Queue list
          Flexible(
            child: StreamBuilder<List<MediaItem>>(
              stream: audioHandler.queue,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final queue = snapshot.data!;
                if (queue.isEmpty) {
                  return const Center(
                    child: Text(
                      'Queue is empty',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return ReorderableListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  itemCount: queue.length,
                  onReorder: (oldIndex, newIndex) async {
                    // Adjust index for the currently playing song
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    await audioHandler.moveQueueItem(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final item = queue[index];
                    final song = _mediaItemToSong(item);

                    return Container(
                      key: ValueKey(item.id),
                      child: Row(
                        children: [
                          // Number
                          Container(
                            width: 40,
                            padding: const EdgeInsets.only(left: 16),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          // Song tile
                          Expanded(
                            child: SongListTile(
                              song: song,
                              position:
                                  index == 0
                                      ? TilePosition.first
                                      : index == queue.length - 1
                                      ? TilePosition.last
                                      : TilePosition.middle,
                              showAddToQueue: false,
                              showRemoveFromQueue: true,
                            ),
                          ),
                          // Drag handle
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.drag_handle,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
