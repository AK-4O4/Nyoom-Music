import 'package:flutter/material.dart';

class CustomPopUpMenu extends StatelessWidget {
  final Widget child;
  final List<PopupMenuEntry> items;
  final Color? backgroundColor;
  final ShapeBorder? shape;
  final Color? barrierColor;

  const CustomPopUpMenu({
    super.key,
    required this.child,
    required this.items,
    this.backgroundColor,
    this.shape,
    this.barrierColor,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(60)),
      color: Colors.black,
      itemBuilder: (context) => items,
      child: child,
    );
  }
}

// Example usage:
/*
CustomPopUpMenu(
  items: [
    PopupMenuItem(
      child: ListTile(
        leading: const Icon(Icons.edit, color: Colors.white),
        title: const Text('Edit', style: TextStyle(color: Colors.white)),
        onTap: () {
          // Handle edit action
        },
      ),
    ),
    PopupMenuItem(
      child: ListTile(
        leading: const Icon(Icons.delete, color: Colors.white),
        title: const Text('Delete', style: TextStyle(color: Colors.white)),
        onTap: () {
          // Handle delete action
        },
      ),
    ),
  ],
  child: IconButton(
    icon: const Icon(Icons.more_vert),
    onPressed: () {},
  ),
)
*/
