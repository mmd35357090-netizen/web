import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../api.dart';
import '../widgets.dart';
import 'sponsored.dart';

/// Watch a sponsored ad to earn coins. The server decides how many coins, how often, and the daily limit.
class WatchEarnScreen extends StatefulWidget {
  const WatchEarnScreen({super.key});

  @override
  State<WatchEarnScreen> createState() => _WatchEarnScreenState();
}

class _WatchEarnScreenState extends State<WatchEarnScreen> {
  static const _imageSeconds = 15;
  SponsoredAd? _ad;
  bool _loading = true;
  bool _started = false;
  bool _claiming = false;
  bool _done = false;
  int _left = 0;
  Timer? _timer;
  VideoPlayerController? _vc;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _vc?.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    final ads = await SponsoredAds.load(force: true);
    if (!mounted) return;
    if (ads.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    // prefer a video ad, otherwise any ad
    final video = ads.where((a) => a.isVideo).toList();
    final pick = (video.isNotEmpty ? video : ads)[DateTime.now().second % (video.isNotEmpty ? video.length : ads.length)];
    setState(() {
      _ad = pick;
      _loading = false;
    });
  }

  Future<void> _start() async {
    final ad = _ad!;
    setState(() => _started = true);
    if (ad.isVideo) {
      final c = VideoPlayerController.networkUrl(Uri.parse(ad.video));
      _vc = c;
      try {
        await c.initialize();
        if (!mounted) return;
        setState(() {});
        await c.play();
        c.addListener(() {
          final v = c.value;
          if (!_done && v.isInitialized && v.duration.inMilliseconds > 0 &&
              v.position.inMilliseconds >= v.duration.inMilliseconds - 300) {
            _finish();
          }
          if (mounted) setState(() {});
        });
      } catch (_) {
        // video could not play: fall back to a timed view of the picture
        _vc = null;
        _timedView();
      }
    } else {
      _timedView();
    }
  }

  void _timedView() {
    setState(() => _left = _imageSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        _finish();
      }
    });
  }

  Future<void> _finish() async {
    if (_done) return;
    _done = true;
    setState(() => _claiming = true);
    final r = await Api.get('posts/promotion-ad-view');
    if (!mounted) return;
    setState(() {
      _claiming = false;
      _message = r.ok
          ? 'Thanks for watching! If you are within today\'s limit, your coins are added to your wallet.'
          : (r.message.isEmpty ? 'Could not record the view.' : r.message);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    final vc = _vc;
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (ad == null) {
      body = const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No sponsored videos right now. Please check again later.', textAlign: TextAlign.center)));
    } else if (_message.isNotEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
            const SizedBox(height: 12),
            Text(_message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Back to wallet')),
          ]),
        ),
      );
    } else if (!_started) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.smart_display_outlined, size: 56),
            const SizedBox(height: 12),
            Text(ad.isVideo ? 'Watch this short video to earn coins.' : 'View this sponsored post for $_imageSeconds seconds to earn coins.',
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            const Text('There is a daily limit, and a short wait between rewards.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _start, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Start')),
          ]),
        ),
      );
    } else {
      body = Column(children: [
        Expanded(
          child: Center(
            child: (ad.isVideo && vc != null && vc.value.isInitialized)
                ? AspectRatio(aspectRatio: vc.value.aspectRatio, child: VideoPlayer(vc))
                : (ad.image.isNotEmpty
                    ? netImage(ad.image, width: double.infinity, height: double.infinity, fit: BoxFit.contain)
                    : const CircularProgressIndicator()),
          ),
        ),
        Container(
          width: double.infinity,
          color: Colors.black,
          padding: const EdgeInsets.all(12),
          child: Text(
            _claiming ? 'Saving...' : (_vc != null ? 'Keep watching until the video ends' : 'Wait $_left s'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ]);
    }
    return Scaffold(
      backgroundColor: _started && _message.isEmpty ? Colors.black : null,
      appBar: AppBar(title: const Text('Watch & Earn')),
      body: body,
    );
  }
}
