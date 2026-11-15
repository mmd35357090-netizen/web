import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../widgets.dart';

class CommentsSheet extends StatefulWidget {
  final AppPost post;
  final VoidCallback onAdded;
  const CommentsSheet({super.key, required this.post, required this.onAdded});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final List<AppComment> _items = [];
  final _ctrl = TextEditingController();
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await Api.get(
        'posts/comment-list?expand=user,isLike&post_id=${widget.post.id}&page=1');
    if (!mounted) return;
    final list = (r.data is Map && r.data['comment'] is Map) ? r.data['comment']['items'] : null;
    setState(() {
      _loading = false;
      if (list is List) {
        _items
          ..clear()
          ..addAll(list.map((e) => AppComment.fromJson(e)));
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final r = await Api.post('posts/add-comment',
        {'post_id': widget.post.id, 'parent_id': 0, 'comment': text, 'type': '1'});
    if (!mounted) return;
    setState(() => _sending = false);
    if (r.ok) {
      _ctrl.clear();
      widget.onAdded();
      _load();
    } else {
      toast(context, r.message.isEmpty ? 'Could not send comment' : r.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(children: [
          const SizedBox(height: 12),
          const Text('Comments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const Divider(height: 20),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('No comments yet'))
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (c, i) {
                          final cm = _items[i];
                          return ListTile(
                            leading: Avatar(cm.user, size: 36),
                            title: Text(cm.user.displayName,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            subtitle: Text(cm.text),
                            trailing: Text(timeAgo(cm.createdAt),
                                style: const TextStyle(fontSize: 12, color: Colors.black45)),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  maxLength: 500,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Write a comment...',
                    counterText: '',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send_rounded),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
