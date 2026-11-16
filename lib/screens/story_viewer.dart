import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../api.dart';
import '../models.dart';
import '../widgets.dart';
import 'story_upload_screen.dart';

/// Stories row for the top of the feed.
class StoriesBar extends StatefulWidget {
  const StoriesBar({super.key});

  @override
  State<StoriesBar> createState() => _StoriesBarState();
}

class _StoriesBarState extends State<StoriesBar> {
  List<UserStories> _stories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Api.get('stories?expand=user,user.userLiveDetail');
    if (!mounted) return;
    final list = r.data is Map ? r.data['story'] : null;
    if (r.ok && list is List) {
      setState(() {
        _stories = list.map((e) => UserStories.fromJson(e)).where((s) => s.items.isNotEmpty).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: _stories.length + 1,
        itemBuilder: (c, i) {
          if (i == 0) {
            return GestureDetector(
              onTap: () async {
                final ok = await Navigator.of(context)
                    .push<bool>(MaterialPageRoute(builder: (_) => const StoryUploadScreen()));
                if (ok == true) _load();
              },
              child: Container(
                width: 72,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(children: [
                  CircleAvatar(
                    radius: 27,
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    child: Icon(Icons.add_rounded, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 4),
                  const Text('Your story', maxLines: 1, style: TextStyle(fontSize: 11)),
                ]),
              ),
            );
          }
          final s = _stories[i - 1];
          return GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                fullscreenDialog: true, builder: (_) => StoryViewer(all: _stories, start: i - 1))),
            child: Container(
              width: 72,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                  ),
                  child: Avatar(s.user, size: 48),
                ),
                const SizedBox(height: 4),
                Text(s.user.displayName,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class StoryViewer extends StatefulWidget {
  final List<UserStories> all;
  final int start;
  const StoryViewer({super.key, required this.all, required this.start});

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  late int _u = widget.start;
  int _i = 0;
  Timer? _timer;
  VideoPlayerController? _vc;
  double _progress = 0;

  UserStories get _cur => widget.all[_u];
  StoryItem get _item => _cur.items[_i];

  @override
  void initState() {
    super.initState();
    _show();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _vc?.dispose();
    super.dispose();
  }

  Future<void> _show() async {
    _timer?.cancel();
    final old = _vc;
    _vc = null;
    old?.dispose();
    setState(() => _progress = 0);
    Api.post('stories/view-counter', {'story_id': _item.id});

    if (_item.isVideo) {
      final c = VideoPlayerController.networkUrl(Uri.parse(_item.video!));
      _vc = c;
      try {
        await c.initialize();
        if (!mounted || _vc != c) return;
        c.play();
        setState(() {});
        _tick(c.value.duration.inMilliseconds.clamp(2000, 30000).toInt());
      } catch (_) {
        _tick(3000);
      }
    } else {
      _tick(5000);
    }
  }

  void _tick(int totalMs) {
    const step = 50;
    int elapsed = 0;
    _timer = Timer.periodic(const Duration(milliseconds: step), (t) {
      elapsed += step;
      if (!mounted) return;
      setState(() => _progress = (elapsed / totalMs).clamp(0.0, 1.0).toDouble());
      if (elapsed >= totalMs) {
        t.cancel();
        _next();
      }
    });
  }

  void _next() {
    if (_i < _cur.items.length - 1) {
      _i++;
      _show();
    } else if (_u < widget.all.length - 1) {
      _u++;
      _i = 0;
      _show();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _prev() {
    if (_i > 0) {
      _i--;
      _show();
    } else if (_u > 0) {
      _u--;
      _i = 0;
      _show();
    } else {
      _show();
    }
  }

  Color _bg() {
    final c = _item.bgColor;
    if (c == null || c.isEmpty) return Colors.black;
    try {
      var h = c.replaceAll('#', '');
      if (h.length == 6) h = 'FF$h';
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    final it = _item;
    Widget media;
    if (it.isVideo && _vc != null && _vc!.value.isInitialized) {
      media = FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(width: _vc!.value.size.width, height: _vc!.value.size.height, child: VideoPlayer(_vc!)),
      );
    } else if (it.image != null && it.image!.isNotEmpty) {
      media = netImage(it.image!, fit: BoxFit.contain, width: double.infinity, height: double.infinity);
    } else {
      media = const SizedBox.shrink();
    }
    return Scaffold(
      backgroundColor: _bg(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Stack(fit: StackFit.expand, children: [
              Positioned.fill(child: media),
              if (it.text.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(it.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
                  ),
                ),
              Row(children: [
                Expanded(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _prev)),
                Expanded(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _next)),
              ]),
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Column(children: [
                  Row(children: [
                    for (int k = 0; k < _cur.items.length; k++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: LinearProgressIndicator(
                            value: k < _i ? 1 : (k == _i ? _progress : 0),
                            minHeight: 3,
                            backgroundColor: Colors.white24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Avatar(_cur.user, size: 32),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_cur.user.displayName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                    Text(timeAgo(it.createdAt), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white)),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
