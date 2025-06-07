import 'package:flutter/material.dart';
import 'package:flutter_sliding_box/flutter_sliding_box.dart';
import 'package:audio_service/audio_service.dart';
import 'tabs/home_tab.dart';
import 'tabs/search_tab.dart';
import 'tabs/playlists_tab.dart';
import '../widgets/player_widget.dart';
import '../widgets/expanded_player_widget.dart';
import '../main.dart';
//import 'package:flutter_appbar/flutter_appbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _controller = BoxController();
  bool _isExpanded = false;

  final List<Widget> _tabs = [
    const HomeTab(),
    const SearchTab(),
    const PlaylistsTab(),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _tabs[_currentIndex],
          StreamBuilder<MediaItem?>(
            stream: audioHandler.mediaItem,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink(); // Hide the player when no song is loaded
              }

              return GestureDetector(
                child: SlidingBox(
                  controller: _controller,
                  minHeight: 70,
                  maxHeight: MediaQuery.of(context).size.height * 0.99,
                  color: Theme.of(context).colorScheme.surface,
                  body: ExpandedPlayerWidget(
                    onMinimize: () => _controller.closeBox(),
                    onShuffleChanged: (enabled) {},
                    onRepeatModeChanged: (mode) {},
                    onVolumeChanged: (volume) {},
                  ),
                  draggableIconVisible: false,
                  collapsed: true,
                  collapsedBody: PlayerWidget(controller: _controller),
                  onBoxSlide: (position) {
                    // Consider it expanded when more than 50% expanded
                    final isExpanded = position > 0.5;
                    if (isExpanded != _isExpanded) {
                      setState(() {
                        _isExpanded = isExpanded;
                      });
                    }
                  },
                ),
              );
            },
          ),
        ],
      ),

      bottomNavigationBar:
          _isExpanded
              ? null // Hide navigation bar when expanded
              : NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.search_outlined),
                    selectedIcon: Icon(Icons.search),
                    label: 'Search',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.playlist_play_outlined),
                    selectedIcon: Icon(Icons.library_music),
                    label: 'Library',
                  ),
                ],
              ),
    );
  }
}
