import 'package:flutter/material.dart';

class DownloadProgressBar extends StatelessWidget {
  final double progress;
  final double height;
  final EdgeInsets margin;

  const DownloadProgressBar({
    super.key,
    required this.progress,
    this.height = 3,
    this.margin = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      height: height,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white.withOpacity(0.1),
          ),
          Container(
            width: MediaQuery.of(context).size.width * progress,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}
