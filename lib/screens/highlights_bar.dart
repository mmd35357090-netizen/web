import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../widgets.dart';
import 'story_viewer.dart';

/// Highlight circles on a profile. Long-press (own profile) deletes one.
class HighlightsBar extends StatefulWidget {
  final int userId;
  final bool own;
  const HighlightsBar({super.key, required this.userId, required this.own});

  @override
  State<HighlightsBar> createState() => _HighlightsBarState();
}

class _HighlightsBarState extends State<HighlightsBar> {
  final List<Map> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Api.get(
        'highlights?expand=highlightStory,highlightStory.story.user&user_id=${widget.userId}');
    if (!mounted) return;
    final l = r.data is Map ? r.data['highlight'] : null;
    if (r.ok && l is List) {
      setState(() {
        _items
          ..clear()
          ..addAll(l.whereType<Map>().where((h) => h['highlightStory'] is List && (h['highlightStory'] as List).isNotEmpty));
      });
    }
  }

  void _open(Map h) {
    final us = UserStories();
    us.user.id = widget.userId;
    us.user.name = str(h['name']);
    final stories = (h['highlightStory'] as List)
        .whereType<Map>()
        .where((x) => x['story'] is Map)
        .map((x) => StoryItem.fromJson(x['story']))
        .toList();
    if (stories.isEmpty) return;
    us.items = stories;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryViewer(all: [us], start: 0)));
  }

  Future<void> _delete(Map h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete highlight?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final r = await Api.delete('highlights/${h['id']}');
    if (!mounted) return;
    if (r.ok) {
      _load();
    } else {
      toast(context, r.message.isEmpty ? 'Could not delete' : r.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 92,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _items.length,
        itemBuilder: (c, i) {
          final h = _items[i];
          final img = str(h['imageUrl']);
          return InkWell(
            onTap: () => _open(h),
            onLongPress: widget.own ? () => _delete(h) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: SizedBox(
                width: 64,
                child: Column(children: [
                  ClipOval(
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: img.isEmpty || img == 'null'
                          ? const ColoredBox(color: Colors.black12, child: Icon(Icons.auto_awesome))
                          : netImage(img, width: 56, height: 56),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(str(h['name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

String str(dynamic v) => v == null ? '' : v.toString();
