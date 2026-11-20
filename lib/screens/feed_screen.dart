import 'package:flutter/material.dart';
import '../api.dart';
import '../config.dart';
import '../models.dart';
import 'post_card.dart';
import 'create_post_screen.dart';
import 'notifications_screen.dart';
import 'search_screen.dart';
import 'story_viewer.dart';
import 'sponsored.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  // Same filters as the Android app: All / Following / Videos / Premium
  static const _chips = ['All', 'Following', 'Videos', 'Premium'];
  static const _queries = [
    'is_recent=1',
    'is_following_user_post=1',
    'is_recent=1&is_video_post=1',
    'is_recent=1&is_premium_post=1',
  ];
  int _seg = 0;

  bool _showHeader = true;

  void _openCreate() =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreatePostScreen()));

  void _openAlerts() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(appBar: AppBar(title: const Text('Notifications')), body: const NotificationsScreen())));

  void _openSearch() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(appBar: AppBar(title: const Text('Search')), body: const SearchScreen())));

  Widget _chipBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Row(children: [
        for (int i = 0; i < _chips.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                if (_seg != i) setState(() => _seg = i);
              },
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: _seg == i ? Colors.black : cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(_chips[i],
                    style: TextStyle(
                        color: _seg == i ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5)),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  // Facebook-style: the header slides away when you scroll down and comes back when you scroll up.
  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (n is ScrollUpdateNotification) {
      final d = n.scrollDelta ?? 0;
      final top = n.metrics.pixels <= 40;
      final want = top || d < -6 ? true : (d > 6 ? false : _showHeader);
      if (want != _showHeader) setState(() => _showHeader = want);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final wide = MediaQuery.of(context).size.width >= 900;
    final show = wide || _showHeader;
    final header = Material(
      color: Colors.white,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!wide)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 0),
            child: Row(children: [
              Expanded(
                child: Text(AppConfig.appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black87)),
              ),
              IconButton(tooltip: 'Search', icon: const Icon(Icons.search_rounded), onPressed: _openSearch),
              IconButton.filled(
                tooltip: 'New post',
                style: IconButton.styleFrom(backgroundColor: Colors.black),
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                onPressed: _openCreate,
              ),
              IconButton(
                tooltip: 'Notifications',
                icon: Icon(Icons.notifications_none_rounded, color: cs.primary),
                onPressed: _openAlerts,
              ),
            ]),
          ),
        Row(children: [
          Expanded(child: _chipBar(cs)),
          if (wide) ...[
            IconButton(tooltip: 'Search', icon: const Icon(Icons.search_rounded), onPressed: _openSearch),
            IconButton(
              tooltip: 'Notifications',
              icon: Icon(Icons.notifications_none_rounded, color: cs.primary),
              onPressed: _openAlerts,
            ),
          ],
        ]),
        const StoriesBar(),
      ]),
    );
    return Column(children: [
      ClipRect(
        child: AnimatedAlign(
          alignment: Alignment.topCenter,
          heightFactor: show ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: header,
        ),
      ),
      Expanded(
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: PostList(key: ValueKey('feed-$_seg'), query: _queries[_seg]),
        ),
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

  List<SponsoredAd> _ads = [];

  @override
  void initState() {
    super.initState();
    SponsoredAds.load().then((a) {
      if (mounted) setState(() => _ads = a);
    }).catchError((_) {});
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
            itemCount: _posts.length + (_ads.isEmpty ? 0 : _posts.length ~/ 6) + 1,
            itemBuilder: (c, i) {
              final adCount = _ads.isEmpty ? 0 : _posts.length ~/ 6;
              if (i == _posts.length + adCount) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                      child: _page <= _pageCount
                          ? const CircularProgressIndicator()
                          : const Text('You are all caught up',
                              style: TextStyle(color: Colors.black45))),
                );
              }
              if (_ads.isNotEmpty && (i + 1) % 7 == 0) {
                return SponsoredCard(_ads[((i + 1) ~/ 7 - 1) % _ads.length]);
              }
              return PostCard(_posts[_ads.isEmpty ? i : i - (i + 1) ~/ 7]);
            },
          ),
        ),
      ),
    );
  }
}
