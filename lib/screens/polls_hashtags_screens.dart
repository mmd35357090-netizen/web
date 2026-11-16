import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets.dart';
import 'hashtag_screen.dart';
import 'paged_list.dart';

class TrendingScreen extends StatefulWidget {
  const TrendingScreen({super.key});

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> {
  String _q = '';
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hashtags')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: TextField(
            onChanged: (v) {
              _t?.cancel();
              _t = Timer(const Duration(milliseconds: 450), () {
                if (mounted) setState(() => _q = v.trim().replaceAll('#', ''));
              });
            },
            decoration: InputDecoration(
              hintText: 'Search hashtags',
              prefixIcon: const Icon(Icons.tag_rounded),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
        Expanded(
          child: PagedList(
            key: ValueKey(_q),
            path: 'posts/hash-counter-list?hashtag=${Uri.encodeQueryComponent(_q)}',
            listKey: 'results',
            empty: 'No hashtags found',
            builder: (c, h) {
              final name = str(h['hashtag']);
              return Card(
                elevation: 0,
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.tag_rounded)),
                  title: Text('#$name', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${str(h['counter'])} posts'),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => HashtagScreen(tag: name))),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class PollsScreen extends StatefulWidget {
  const PollsScreen({super.key});

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> {
  List<Map> _polls = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Api.get('polls?expand=pollOptions&category_id=&title=');
    if (!mounted) return;
    setState(() {
      _loading = false;
      final p = r.data is Map ? r.data['poll'] : null;
      if (r.ok && p is Map && p['items'] is List) {
        _polls = (p['items'] as List).whereType<Map>().toList();
      } else if (!r.ok) {
        _error = r.message;
      }
    });
  }

  Future<void> _vote(Map poll, Map opt) async {
    final r = await Api.post('poll-question-answers/add-answer',
        {'poll_id': '${poll['id']}', 'question_option_id': '${opt['id']}'});
    if (!mounted) return;
    if (r.ok) {
      await _load();
    } else {
      toast(context, r.message.isEmpty ? 'Could not vote' : r.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_polls.isEmpty) {
      body = Center(child: Text(_error.isEmpty ? 'No polls right now' : _error));
    } else {
      body = ListView(padding: const EdgeInsets.all(10), children: [for (final p in _polls) _card(p)]);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Polls')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: body),
      ),
    );
  }

  Widget _card(Map p) {
    final opts = p['pollOptions'] is List ? (p['pollOptions'] as List).whereType<Map>().toList() : <Map>[];
    final voted = (int.tryParse('${p['is_vote']}') ?? 0) != 0;
    final total = int.tryParse('${p['total_vote_count']}') ?? 0;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(str(p['title']), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final o in opts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: voted ? _result(o, total) : OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42), alignment: Alignment.centerLeft),
                onPressed: () => _vote(p, o),
                child: Text(str(o['title'])),
              ),
            ),
          Text('$total votes', style: const TextStyle(color: Colors.black45, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _result(Map o, int total) {
    final n = int.tryParse('${o['total_option_vote_count']}') ?? 0;
    final f = total == 0 ? 0.0 : (n / total).clamp(0.0, 1.0).toDouble();
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(value: f, minHeight: 42, backgroundColor: Colors.black12),
      ),
      Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Expanded(child: Text(str(o['title']))),
            Text('${(f * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    ]);
  }
}
