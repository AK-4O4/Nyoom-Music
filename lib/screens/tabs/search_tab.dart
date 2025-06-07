import 'package:flutter/material.dart';
import '../../models/song_model.dart';
import '../../services/youtube_music_service.dart';
import '../../widgets/song_list_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import '../../main.dart';
import 'dart:async';
import '../../widgets/app_bar_widget.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  final _musicService = YoutubeMusicService();
  List<Song> _searchResults = [];
  List<String> _recentSearches = [];
  List<String> _searchSuggestions = [];
  bool _isLoading = false;
  String? _error;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final searches = prefs.getStringList('recent_searches') ?? [];
      setState(() {
        _recentSearches = searches;
      });
    } catch (e) {
      print('Error loading recent searches: $e');
    }
  }

  Future<void> _addToRecentSearches(String query) async {
    if (query.trim().isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final searches = prefs.getStringList('recent_searches') ?? [];

      // Remove if already exists and add to the beginning
      searches.remove(query);
      searches.insert(0, query);

      // Keep only the last 10 searches
      if (searches.length > 10) {
        searches.removeLast();
      }

      await prefs.setStringList('recent_searches', searches);
      setState(() {
        _recentSearches = searches;
      });
    } catch (e) {
      print('Error saving recent search: $e');
    }
  }

  Future<void> _removeFromRecentSearches(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final searches = prefs.getStringList('recent_searches') ?? [];
      searches.remove(query);
      await prefs.setStringList('recent_searches', searches);
      setState(() {
        _recentSearches = searches;
      });
    } catch (e) {
      print('Error removing recent search: $e');
    }
  }

  Future<void> _clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('recent_searches');
      setState(() {
        _recentSearches = [];
      });
    } catch (e) {
      print('Error clearing recent searches: $e');
    }
  }

  Future<void> _getSearchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchSuggestions = [];
      });
      return;
    }

    try {
      final suggestions = await _musicService.getSearchSuggestions(query);
      if (mounted) {
        setState(() {
          _searchSuggestions = suggestions;
        });
      }
    } catch (e) {
      print('Error getting search suggestions: $e');
    }
  }

  Future<void> _performSearch(String query) async {
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchSuggestions = [];
        _error = null;
      });
      return;
    }

    // Debounce search suggestions
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _getSearchSuggestions(query);
    });

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _musicService.searchSongs(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error searching: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _musicService.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            appBarWidget(context),
            const Row(
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 16, right: 16, top: 30),
                  child: Text(
                    'Search',
                    textAlign: TextAlign.left,
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 30),
              child: SearchBar(
                controller: _searchController,
                hintText: 'Search for songs...',
                leading: const Icon(Icons.search),
                trailing: [
                  if (_searchController.text.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        if (_searchController.text.trim().isNotEmpty) {
                          _performSearch(_searchController.text);
                          _addToRecentSearches(_searchController.text);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch('');
                      },
                    ),
                  ],
                ],
                onChanged: (value) {
                  // Only get suggestions when typing, don't save to recent searches yet
                  _getSearchSuggestions(value);
                },
                onSubmitted: (value) {
                  // When the user hits enter or taps the search button
                  if (value.trim().isNotEmpty) {
                    _performSearch(value);
                    _addToRecentSearches(
                      value,
                    ); // Explicitly add to recent searches
                  }
                },
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 16.0),
                ),
                elevation: WidgetStateProperty.all(0),
              ),
            ),
            if (_isLoading)
              SizedBox(
                height: MediaQuery.of(context).size.height - 200,
                child: const Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SizedBox(
                height: MediaQuery.of(context).size.height - 200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _performSearch(_searchController.text),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_searchResults.isNotEmpty)
              SizedBox(
                height: MediaQuery.of(context).size.height + 1000,
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  physics: NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final song = _searchResults[index];
                    final itemCount = _searchResults.length;
                    // Set position based on index
                    final position = itemCount == 1
                        ? TilePosition.single
                        : index == 0
                            ? TilePosition.first
                            : index == itemCount - 1
                                ? TilePosition.last
                                : TilePosition.middle;

                    return SongListTile(song: song, position: position);
                  },
                ),
              )
            else if (_searchSuggestions.isNotEmpty)
              SizedBox(
                height: MediaQuery.of(context).size.height - 200,
                child: ListView.builder(
                  itemCount: _searchSuggestions.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.search),
                      title: Text(_searchSuggestions[index]),
                      onTap: () {
                        final suggestion = _searchSuggestions[index];
                        _searchController.text = suggestion;
                        _searchController.selection =
                            TextSelection.fromPosition(
                          TextPosition(offset: _searchController.text.length),
                        );
                        _performSearch(suggestion);
                        _addToRecentSearches(
                          suggestion,
                        ); // Add to recent searches when suggestion clicked
                      },
                    );
                  },
                ),
              )
            else if (_searchController.text.isEmpty)
              SizedBox(
                height: MediaQuery.of(context).size.height - 200,
                child: _recentSearches.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search,
                              size: 80,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            SizedBox(height: 16),
                            Text('Search for songs to get started'),
                          ],
                        ),
                      )
                    : ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Recent Searches',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _clearRecentSearches,
                                  child: const Text('Clear All'),
                                ),
                              ],
                            ),
                          ),
                          ...List.generate(
                            _recentSearches.length,
                            (index) => ListTile(
                              leading: const Icon(Icons.history),
                              title: Text(_recentSearches[index]),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => _removeFromRecentSearches(
                                  _recentSearches[index],
                                ),
                              ),
                              onTap: () {
                                final recentSearch = _recentSearches[index];
                                _searchController.text = recentSearch;
                                _searchController.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(
                                    offset: _searchController.text.length,
                                  ),
                                );
                                _performSearch(recentSearch);
                                _addToRecentSearches(
                                  recentSearch,
                                ); // Re-add to top of recent searches
                              },
                            ),
                          ),
                        ],
                      ),
              )
            else
              const Expanded(child: Center(child: Text('No results found'))),
            if (_searchResults.isNotEmpty)
              StreamBuilder<MediaItem?>(
                stream: audioHandler.mediaItem,
                builder: (context, snapshot) {
                  final bool songIsPlaying = snapshot.hasData;
                  return SizedBox(height: songIsPlaying ? 80.0 : 16.0);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
