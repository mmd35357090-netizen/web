import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../widgets.dart';
import 'paged_list.dart';

class PodcastsScreen extends StatelessWidget {
  const PodcastsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Podcasts')),
      body: PagedList(
        path: 'podcast-shows?expand=podcastShow',
        listKey: 'podcast_show',
        empty: 'No podcasts yet',
        builder: (c, s) {
          final img = str(s['imageUrl']);
          return Card(
            elevation: 0,
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: img.isEmpty
                      ? const ColoredBox(color: Colors.black12, child: Icon(Icons.podcasts_rounded))
                      : netImage(img, width: 56, height: 56),
                ),
              ),
              title: Text(str(s['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(str(s['description']), maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => PodcastShowScreen(show: s))),
            ),
          );
        },
      ),
    );
  }
}

class PodcastShowScreen extends StatefulWidget {
  final Map show;
  const PodcastShowScreen({super.key, required this.show});

  @override
  State<PodcastShowScreen> createState() => _PodcastShowScreenState();
}

class _PodcastShowScreenState extends State<PodcastShowScreen> {
  VideoPlayerController? _vc;
  String _playing = '';
  String _nowName = '';
  bool _loadingAudio = false;
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    _vc?.dispose();
    super.dispose();
  }

  Future<void> _play(Map ep) async {
    final url = str(ep['audioUrl']);
    if (url.isEmpty) return;
    if (_playing == url && _vc != null) {
      _vc!.value.isPlaying ? await _vc!.pause() : await _vc!.play();
      setState(() {});
      return;
    }
    setState(() {
      _loadingAudio = true;
      _playing = url;
      _nowName = str(ep['name']);
    });
    await _vc?.dispose();
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    _vc = c;
    try {
      await c.initialize();
      await c.play();
      _tick?.cancel();
      _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted) setState(() {});
      });
    } catch (_) {
      if (mounted) toast(context, 'This episode could not be played');
    }
    if (mounted) setState(() => _loadingAudio = false);
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final vc = _vc;
    final ready = vc != null && vc.value.isInitialized;
    return Scaffold(
      appBar: AppBar(title: Text(str(widget.show['name']))),
      body: Column(children: [
        Expanded(
          child: PagedList(
            path: 'podcast-shows/podcast-show-episodes?podcast_show_id=${widget.show['id']}',
            listKey: 'podcastShowEpisode',
            empty: 'No episodes yet',
            builder: (c, ep) {
              final url = str(ep['audioUrl']);
              final active = url == _playing && ready && vc.value.isPlaying;
              return Card(
                elevation: 0,
                child: ListTile(
                  leading: Icon(active ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, size: 38),
                  title: Text(str(ep['name'])),
                  subtitle: Text(str(ep['episode_period'])),
                  onTap: () => _play(ep),
                ),
              );
            },
          ),
        ),
        if (_playing.isNotEmpty)
          Material(
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_nowName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (_loadingAudio)
                  const LinearProgressIndicator()
                else if (ready)
                  Row(children: [
                    IconButton(
                      icon: Icon(vc.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      onPressed: () async {
                        vc.value.isPlaying ? await vc.pause() : await vc.play();
                        setState(() {});
                      },
                    ),
                    Text(_fmt(vc.value.position)),
                    Expanded(
                      child: Slider(
                        value: vc.value.position.inMilliseconds
                            .clamp(0, vc.value.duration.inMilliseconds == 0 ? 1 : vc.value.duration.inMilliseconds)
                            .toDouble(),
                        max: (vc.value.duration.inMilliseconds == 0 ? 1 : vc.value.duration.inMilliseconds).toDouble(),
                        onChanged: (v) => vc.seekTo(Duration(milliseconds: v.toInt())),
                      ),
                    ),
                    Text(_fmt(vc.value.duration)),
                  ]),
              ]),
            ),
          ),
      ]),
    );
  }
}
