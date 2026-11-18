import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../api.dart';
import '../models.dart';
import '../widgets.dart';
import 'comments_sheet.dart';
import 'profile_screen.dart';
import '../links.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final List<AppPost> _reels = [];
  final _pc = PageController();
  int _current = 0;
  int _page = 1;
  int _pageCount = 1;
  bool _loading = false;
  bool _first = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || _page > _pageCount) return;
    _loading = true;
    final r = await Api.get(
        'posts/search-post?expand=user.isFollowing,isFavorite&is_recent=1&is_video_post=1&page=$_page');
    if (!mounted) return;
    setState(() {
      _loading = false;
      _first = true;
      final d = r.data is Map ? r.data['post'] : null;
      if (r.ok && d is Map) {
        final items = d['items'];
        if (items is List) {
          _reels.addAll(items
              .map((e) => AppPost.fromJson(e))
              .where((x) => x.id > 0 && x.media.any((m) => m.isVideo)));
        }
        final meta = d['_meta'];
        if (meta is Map) _pageCount = int.tryParse('${meta['pageCount']}') ?? _page;
        _page += 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_first) return const ColoredBox(color: Colors.black, child: Center(child: CircularProgressIndicator()));
    if (_reels.isEmpty) {
      return const ColoredBox(
          color: Colors.black,
          child: Center(child: Text('No reels yet', style: TextStyle(color: Colors.white))));
    }
    return ColoredBox(
      color: Colors.black,
      child: PageView.builder(
        controller: _pc,
        scrollDirection: Axis.vertical,
        itemCount: _reels.length,
        onPageChanged: (i) {
          setState(() => _current = i);
          if (i >= _reels.length - 3) _load();
        },
        itemBuilder: (c, i) => _ReelItem(
          post: _reels[i],
          active: i == _current,
          muted: _muted,
          onToggleMute: () => setState(() => _muted = !_muted),
        ),
      ),
    );
  }
}

class _ReelItem extends StatefulWidget {
  final AppPost post;
  final bool active;
  final bool muted;
  final VoidCallback onToggleMute;
  const _ReelItem(
      {required this.post, required this.active, required this.muted, required this.onToggleMute});

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
  VideoPlayerController? _vc;
  bool _ready = false;
  bool _failed = false;

  AppPost get p => widget.post;

  @override
  void initState() {
    super.initState();
    if (widget.active) _init();
  }

  @override
  void didUpdateWidget(covariant _ReelItem old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      if (_vc == null) {
        _init();
      } else {
        _vc!.seekTo(Duration.zero);
        _vc!.play();
      }
    } else if (!widget.active && old.active) {
      _vc?.pause();
    }
    _vc?.setVolume(widget.muted ? 0 : 1);
  }

  Future<void> _init() async {
    final m = p.media.firstWhere((x) => x.isVideo, orElse: () => p.media.first);
    final c = VideoPlayerController.networkUrl(Uri.parse(m.url));
    _vc = c;
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(widget.muted ? 0 : 1);
      if (!mounted) return;
      setState(() => _ready = true);
      if (widget.active) c.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _vc?.dispose();
    super.dispose();
  }

  Future<void> _like() async {
    final was = p.isLiked;
    setState(() {
      p.isLiked = !was;
      p.likes += was ? -1 : 1;
    });
    final r = await Api.post(was ? 'posts/unlike' : 'posts/like', {'post_id': p.id});
    if (!r.ok && mounted) {
      setState(() {
        p.isLiked = was;
        p.likes += was ? 1 : -1;
      });
    }
  }

  void _comments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => CommentsSheet(post: p, onAdded: () => setState(() => p.comments += 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final thumb = p.media.firstWhere((x) => x.isVideo, orElse: () => p.media.first).thumb;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Stack(fit: StackFit.expand, children: [
          GestureDetector(
            onTap: () {
              final c = _vc;
              if (c == null || !_ready) return;
              if (widget.muted) {
                widget.onToggleMute();
              } else {
                c.value.isPlaying ? c.pause() : c.play();
                setState(() {});
              }
            },
            child: _ready && _vc != null
                ? FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: _vc!.value.size.width,
                      height: _vc!.value.size.height,
                      child: VideoPlayer(_vc!),
                    ),
                  )
                : (thumb != null && thumb.isNotEmpty
                    ? netImage(thumb, width: double.infinity, height: double.infinity)
                    : const ColoredBox(color: Colors.black)),
          ),
          if (!_ready && !_failed) const Center(child: CircularProgressIndicator(color: Colors.white)),
          if (_failed)
            const Center(child: Text('Video could not be played', style: TextStyle(color: Colors.white))),
          if (_ready && widget.muted)
            const Positioned(
              top: 16,
              left: 16,
              child: Icon(Icons.volume_off_rounded, color: Colors.white70),
            ),
          Positioned(
            right: 10,
            bottom: 90,
            child: Column(children: [
              IconButton(
                onPressed: _like,
                icon: Icon(p.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: p.isLiked ? Colors.red : Colors.white, size: 32),
              ),
              Text('${p.likes}', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 14),
              if (p.commentsEnabled) ...[
                IconButton(
                  onPressed: _comments,
                  icon: const Icon(Icons.mode_comment_outlined, color: Colors.white, size: 30),
                ),
                Text('${p.comments}', style: const TextStyle(color: Colors.white)),
              ],
              const SizedBox(height: 14),
              IconButton(
                tooltip: 'Share',
                onPressed: () => AppLinks.share(context, AppLinks.post(p.id), title: 'Reel'),
                icon: const Icon(Icons.share_outlined, color: Colors.white, size: 30),
              ),
            ]),
          ),
          Positioned(
            left: 14,
            right: 80,
            bottom: 24,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => ProfileScreen(userId: p.user.id))),
                child: Row(children: [
                  Avatar(p.user, size: 34),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(p.user.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
              if (p.title.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(p.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
