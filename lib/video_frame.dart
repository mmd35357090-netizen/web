import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

@JS('cfgVideoFrame')
external JSPromise<JSObject?> _cfgVideoFrame(JSUint8Array bytes, JSString mime);

class VideoFrame {
  final Uint8List jpeg;
  final int width;
  final int height;
  VideoFrame(this.jpeg, this.width, this.height);
}

/// Takes one picture from a video in the browser, to use as its cover. Returns null if the browser can't.
Future<VideoFrame?> grabVideoFrame(Uint8List bytes, String mime) async {
  try {
    final o = await _cfgVideoFrame(bytes.toJS, mime.toJS).toDart;
    if (o == null) return null;
    final data = (o.getProperty<JSUint8Array>('data'.toJS)).toDart;
    final w = o.getProperty<JSNumber>('width'.toJS).toDartInt;
    final h = o.getProperty<JSNumber>('height'.toJS).toDartInt;
    if (data.isEmpty) return null;
    return VideoFrame(data, w, h);
  } catch (_) {
    return null;
  }
}

/// First picture of a video, for posts that have no cover image.
class VideoPoster extends StatefulWidget {
  final String url;
  const VideoPoster(this.url, {super.key});

  @override
  State<VideoPoster> createState() => _VideoPosterState();
}

class _VideoPosterState extends State<VideoPoster> {
  VideoPlayerController? _c;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _c = c;
      await c.initialize();
      await c.setVolume(0);
      await c.seekTo(const Duration(milliseconds: 150));
      await c.pause();
      if (mounted) setState(() => _ready = true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (!_ready || c == null) return Container(color: const Color(0xFFE9ECF3));
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
    );
  }
}
