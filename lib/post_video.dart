import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'widgets.dart';

/// Plays a post's video right in the feed: tap to play or pause, speaker button for sound.
/// Only one video plays at a time.
class PostVideo extends StatefulWidget {
  final String url;
  final String? thumb;
  const PostVideo(this.url, {this.thumb, super.key});

  static VideoPlayerController? _current;

  @override
  State<PostVideo> createState() => _PostVideoState();
}

class _PostVideoState extends State<PostVideo> {
  VideoPlayerController? _c;
  bool _loading = false;
  bool _failed = false;
  bool _muted = false;

  Future<void> _start() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _c = c;
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(1);
      PostVideo._current?.pause();
      PostVideo._current = c;
      c.addListener(() {
        if (mounted) setState(() {});
      });
      await c.play();
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
          _c = null;
        });
      }
    }
  }

  Future<void> _tap() async {
    final c = _c;
    if (c == null || !c.value.isInitialized) {
      await _start();
      return;
    }
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      PostVideo._current?.pause();
      PostVideo._current = c;
      await c.play();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (identical(PostVideo._current, _c)) PostVideo._current = null;
    _c?.dispose();
    super.dispose();
  }

  Widget _cover() {
    final t = widget.thumb ?? '';
    if (t.isNotEmpty) return netImage(t, width: double.infinity, height: double.infinity);
    return const ColoredBox(color: Colors.black);
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    return GestureDetector(
      onTap: _tap,
      child: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: Colors.black),
        if (ready)
          FittedBox(
            fit: BoxFit.contain,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
                width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
          )
        else
          _cover(),
        if (_loading) const Center(child: CircularProgressIndicator(color: Colors.white)),
        if (!_loading && (!ready || !c.value.isPlaying))
          Center(
            child: _failed
                ? const Text('Video could not be played', style: TextStyle(color: Colors.white))
                : const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 56),
          ),
        if (ready)
          Positioned(
            right: 6,
            top: 6,
            child: Material(
              color: Colors.black45,
              shape: const CircleBorder(),
              child: IconButton(
                iconSize: 20,
                color: Colors.white,
                icon: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
                onPressed: () {
                  setState(() => _muted = !_muted);
                  c.setVolume(_muted ? 0 : 1);
                },
              ),
            ),
          ),
        if (ready)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(c, allowScrubbing: true, padding: const EdgeInsets.only(top: 6)),
          ),
      ]),
    );
  }
}
