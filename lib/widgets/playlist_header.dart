import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PlaylistHeader extends StatelessWidget {
  final String title;
  final int songsCount;
  final IconData icon;
  final Color iconColor;
  final String? imageUrl;
  final String? artist;

  const PlaylistHeader({
    super.key,
    required this.title,
    required this.songsCount,
    required this.icon,
    required this.iconColor,
    this.imageUrl,
    this.artist,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    final imageSize = isSmallScreen ? 120.0 : 160.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Hero(
            tag: 'album-art-$title',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl!,
                      width: imageSize,
                      height: imageSize,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildPlaceholder(
                        context,
                        imageSize,
                        icon,
                        iconColor,
                      ),
                      errorWidget: (context, url, error) => _buildPlaceholder(
                        context,
                        imageSize,
                        icon,
                        iconColor,
                      ),
                    )
                  : _buildPlaceholder(
                      context,
                      imageSize,
                      icon,
                      iconColor,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (artist != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person,
                  size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                artist!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Text(
              '$songsCount ${songsCount == 1 ? 'song' : 'songs'}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaceholder(
    BuildContext context,
    double size,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        size: size * 0.4,
        color: iconColor,
      ),
    );
  }
}
