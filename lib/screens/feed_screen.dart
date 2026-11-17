import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import 'post_card.dart';
import 'explore_hub.dart';
import 'search_screen.dart';
import 'story_viewer.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const StoriesBar(),
      Material(
        color: Colors.white,
        child: Row(children: [
          Expanded(
            child: TabBar(controller: _tabs, tabs: const [Tab(text: 'For you'), Tab(text: 'Following')]),
          ),
          IconButton(
            tooltip: 'Explore',
            icon: const Icon(Icons.apps_rounded),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ExploreHub())),
          ),
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => Scaffold(appBar: AppBar(title: const Text('Search')), body: const SearchScreen()))),
          ),
        ]),
      ),
      Expanded(
        child: TabBarView(controller: _tabs, children: const [
          PostList(query: 'is_recent=1'),
          PostList(query: 'is_following_user_post=1'),
        ]),
      ),
    ]);
  }
}

/// Endless list of posts. Reused by the feed and by profile pages.
class PostList extends StatefulWidget {
  final String query;
  final bool shrink;
  const PostList({super.key, required this.query, this.shrink = false});

  @override
  State<PostList> createState() => _PostListState();
}

class _PostListState extends State<PostList> with AutomaticKeepAliveClientMixin {
  final List<AppPost> _posts = [];
  final _scroll = ScrollController();
  int _page = 1;
  int _pageCount = 1;
  bool _loading = false;
  bool _firstDone = false;
  String _error = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _page = 1;
    _pageCount = 1;
    _posts.clear();
    _firstDone = false;
    await _load();
  }

  Future<void> _load() async {
    if (_loading || _page > _pageCount) return;
    _loading = true;
    final r = await Api.get(
        'posts/search-post?expand=user.isFollowing,isFavorite,isPin&${widget.query}&page=$_page');
    if (!mounted) return;
    setState(() {
      _loading = false;
      _firstDone = true;
      if (!r.ok) {
        _error = r.message;
        return;
      }
      _error = '';
      final d = r.data is Map ? r.data['post'] : null;
      if (d is Map) {
        final items = d['items'];
        if (items is List) {
          _posts.addAll(items.map((e) => AppPost.fromJson(e)).where((x) => x.id > 0));
        }
        final meta = d['_meta'];
        if (meta is Map) {
          _pageCount = int.tryParse('${meta['pageCount']}') ?? _page;
        }
        _page += 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_firstDone) return const Center(child: CircularProgressIndicator());
    if (_posts.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error.isEmpty ? 'Nothing here yet' : _error),
          TextButton(onPressed: _refresh, child: const Text('Reload')),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(10),
            itemCount: _posts.length + 1,
            itemBuilder: (c, i) {
              if (i == _posts.length) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                      child: _page <= _pageCount
                          ? const CircularProgressIndicator()
                          : const Text('You are all caught up',
                              style: TextStyle(color: Colors.black45))),
                );
              }
              return PostCard(_posts[i]);
            },
          ),
        ),
      ),
    );
  }
}
