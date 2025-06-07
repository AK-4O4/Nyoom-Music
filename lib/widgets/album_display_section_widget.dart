import 'package:flutter/material.dart';
import '../models/album_model.dart';
import '../screens/playlist_screen.dart';

class AlbumDisplaySectionWidget extends StatelessWidget {
  final List<Album> albums;
  final String title;
  final VoidCallback? onSeeAllPressed;

  const AlbumDisplaySectionWidget({
    super.key,
    required this.albums,
    required this.title,
    this.onSeeAllPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and See All row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if (onSeeAllPressed != null)
              TextButton(
                onPressed: onSeeAllPressed,
                child: const Text('See All'),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Album slider
        SizedBox(
          height: 200, // Fixed height for the album slider
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              return _buildAlbumCard(context, album);
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAlbumCard(BuildContext context, Album album) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => PlaylistScreen(
                    title: album.title,
                    type: PlaylistType.custom,
                    albumId: album.id,
                  ),
            ),
          );
        },
        child: SizedBox(
          width: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Album Artwork with elevation
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child:
                      album.thumbnailUrl.isNotEmpty
                          ? Image.network(
                            album.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.1),
                                child: const Center(
                                  child: Icon(Icons.album, size: 50),
                                ),
                              );
                            },
                          )
                          : Container(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1),
                            child: const Center(
                              child: Icon(Icons.album, size: 50),
                            ),
                          ),
                ),
              ),
              const SizedBox(height: 4),
              // Album title with overflow ellipsis
              Text(
                album.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              // Artist name with overflow ellipsis
              Text(
                album.artist,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
