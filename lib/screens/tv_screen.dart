import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:web/web.dart' as web;
import '../widgets.dart';
import 'paged_list.dart';

class TvScreen extends StatelessWidget {
  const TvScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('TV'),
          bottom: const TabBar(tabs: [Tab(text: 'Shows'), Tab(text: 'Channels')]),
        ),
        body: TabBarView(children: [
          PagedList(
            path: 'live-tvs/tv-shows?expand=tvShowEpisode,rating',
            listKey: 'tv_show',
            empty: 'No shows yet',
            builder: (c, s) => _tile(
              c,
              title: str(s['name']),
              sub: str(s['description']),
              img: str(s['imageUrl']),
              onTap: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => TvShowScreen(show: s))),
            ),
          ),
          PagedList(
            path: 'live-tvs?expand=currentViewer',
            listKey: 'live_tv',
            empty: 'No channels yet',
            builder: (c, t) {
              final locked = '${t['is_paid']}' == '1' && '${t['is_subscribed']}' != '1';
              return _tile(
                c,
                title: str(t['name']),
                sub: locked ? 'Paid channel (use the mobile app)' : str(t['description']),
                img: str(t['imageUrl']),
                live: '${t['is_live']}' == '1',
                onTap: locked
                    ? () => toast(c, 'This channel needs coins. Open it in the mobile app.')
                    : () => Navigator.of(c).push(MaterialPageRoute(
                        builder: (_) => VideoScreen(title: str(t['name']), url: str(t['tv_url'])))),
              );
            },
          ),
        ]),
      ),
    );
  }

  Widget _tile(BuildContext c,
      {required String title, required String sub, required String img, required VoidCallback onTap, bool live = false}) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 64,
            height: 48,
            child: img.isEmpty || img == 'null'
                ? const ColoredBox(color: Colors.black12, child: Icon(Icons.tv_rounded))
                : netImage(img, width: 64, height: 48),
          ),
        ),
        title: Row(children: [
          Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
          if (live)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
              child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
        ]),
        subtitle: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: onTap,
      ),
    );
  }
}

class TvShowScreen extends StatelessWidget {
  final Map show;
  const TvShowScreen({super.key, required this.show});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(str(show['name']))),
      body: PagedList(
        path: 'tv-shows/tv-show-episodes?tv_show_id=${show['id']}',
        listKey: 'tvShowEpisode',
        empty: 'No episodes yet',
        builder: (c, e) {
          final img = str(e['imageUrl']);
          return Card(
            elevation: 0,
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 64,
                  height: 48,
                  child: img.isEmpty || img == 'null'
                      ? const ColoredBox(color: Colors.black12, child: Icon(Icons.play_circle_outline))
                      : netImage(img, width: 64, height: 48),
                ),
              ),
              title: Text(str(e['name'])),
              subtitle: Text(str(e['episode_period'])),
              onTap: () => Navigator.of(c).push(
                  MaterialPageRoute(builder: (_) => VideoScreen(title: str(e['name']), url: str(e['videoUrl'])))),
            ),
          );
        },
      ),
    );
  }
}

/// Plays mp4 / webm. Live HLS (.m3u8) streams are not supported by most browsers, so they open in a new tab.
class VideoScreen extends StatefulWidget {
  final String title;
  final String url;
  const VideoScreen({super.key, required this.title, required this.url});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  VideoPlayerController? _c;
  bool _failed = false;

  bool get _hls => widget.url.toLowerCase().contains('.m3u8');

  @override
  void initState() {
    super.initState();
    if (widget.url.isEmpty) {
      _failed = true;
      return;
    }
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _c = c;
    c.initialize().then((_) {
      if (mounted) {
        setState(() {});
        c.play();
      }
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    Widget body;
    if (_failed || (_hls && (c == null || !c.value.isInitialized))) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.live_tv_rounded, size: 48),
          const SizedBox(height: 10),
          const Text('This stream cannot play inside the page.'),
          const SizedBox(height: 10),
          if (widget.url.isNotEmpty)
            FilledButton(
              onPressed: () => web.window.open(widget.url, '_blank'),
              child: const Text('Open in new tab'),
            ),
        ]),
      );
    } else if (c == null || !c.value.isInitialized) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = Column(children: [
        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: () => setState(() => c.value.isPlaying ? c.pause() : c.play()),
              child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
            ),
          ),
        ),
        VideoProgressIndicator(c, allowScrubbing: true),
      ]);
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.title)),
      body: body,
    );
  }
}
