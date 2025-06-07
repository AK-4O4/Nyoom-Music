import 'package:flutter/material.dart';
import '../models/album_model.dart';
import '../screens/playlist_screen.dart';

enum TilePosition { single, first, middle, last }

class AlbumListTile extends StatelessWidget {
  final Album album;
  final VoidCallback? onTap;
  final TilePosition position;
  final bool isLiked;
  final Function(bool) onLikeChanged;

  const AlbumListTile({
    super.key,
    required this.album,
    this.onTap,
    this.position = TilePosition.middle,
    required this.isLiked,
    required this.onLikeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    final thumbnailSize = isSmallScreen ? 40.0 : 48.0;

    BorderRadius borderRadius;
    switch (position) {
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

    return Container(
      margin: EdgeInsets.only(
        bottom: position == TilePosition.last || position == TilePosition.single
            ? size.height * 0.01
            : 1,
        left: size.width * 0.05,
        right: size.width * 0.05,
        top: position == TilePosition.first || position == TilePosition.single
            ? size.height * 0.000001
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
          tag: 'album-art-${album.id}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: album.thumbnailUrl.isNotEmpty
                ? Image.network(
                    album.thumbnailUrl,
                    width: thumbnailSize,
                    height: thumbnailSize,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: thumbnailSize,
                      height: thumbnailSize,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      child: Icon(Icons.album, size: thumbnailSize * 0.5),
                    ),
                  )
                : Container(
                    width: thumbnailSize,
                    height: thumbnailSize,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    child: Icon(Icons.album, size: thumbnailSize * 0.5),
                  ),
          ),
        ),
        title: Text(
          album.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
        ),
        subtitle: Text(
          album.artist + "\n" + album.songCount.toString() + " Songs",
          style: TextStyle(
            color: Colors.white70,
            fontSize: isSmallScreen ? 12 : 14,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlaylistScreen(
                title: album.title,
                type: PlaylistType.custom,
                albumId: album.id,
              ),
            ),
          );
        },
        trailing: IconButton(
          icon: Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            color: isLiked ? Colors.red : null,
          ),
          onPressed: () => onLikeChanged(!isLiked),
        ),
      ),
    );
  }
}
