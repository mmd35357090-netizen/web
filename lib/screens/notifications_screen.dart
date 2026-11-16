import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../widgets.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<AppNotification> _items = [];
  final _scroll = ScrollController();
  int _page = 1;
  int _pageCount = 1;
  bool _loading = false;
  bool _first = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _items.clear();
    _page = 1;
    _pageCount = 1;
    await _load();
  }

  Future<void> _load() async {
    if (_loading || _page > _pageCount) return;
    _loading = true;
    final r = await Api.get('notifications?expand=createdByUser,refrenceDetails&page=$_page');
    if (!mounted) return;
    setState(() {
      _loading = false;
      _first = true;
      final d = r.data is Map ? r.data['notification'] : null;
      if (r.ok && d is Map) {
        final items = d['items'];
        if (items is List) _items.addAll(items.map((e) => AppNotification.fromJson(e)));
        final meta = d['_meta'];
        if (meta is Map) _pageCount = int.tryParse('${meta['pageCount']}') ?? _page;
        _page += 1;
      }
    });
  }

  Future<void> _markAll() async {
    final r = await Api.post('notifications/update-read-status', {'id': 0, 'is_read_all': 1});
    if (r.ok && mounted) setState(() => _items.forEach((n) => n.read = true));
  }

  void _open(AppNotification n) {
    if (!n.read) {
      Api.post('notifications/update-read-status', {'id': n.id, 'is_read_all': 0});
      setState(() => n.read = true);
    }
    final nav = Navigator.of(context);
    if (n.type == 1 && n.by != null && n.by!.id > 0) {
      nav.push(MaterialPageRoute(builder: (_) => ProfileScreen(userId: n.by!.id)));
    } else if ((n.type == 2 || n.type == 3 || n.type == 7) && n.refId > 0) {
      nav.push(MaterialPageRoute(builder: (_) => PostDetailScreen(postId: n.refId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_first) return const Center(child: CircularProgressIndicator());
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(children: [
              const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton(onPressed: _markAll, child: const Text('Mark all read')),
            ]),
          ),
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('No notifications'))
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      controller: _scroll,
                      itemCount: _items.length,
                      itemBuilder: (c, i) {
                        final n = _items[i];
                        return ListTile(
                          tileColor: n.read ? null : Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                          leading: n.by != null ? Avatar(n.by!, size: 42) : const CircleAvatar(child: Icon(Icons.notifications)),
                          title: Text(n.message.isNotEmpty ? n.message : n.title,
                              maxLines: 3, overflow: TextOverflow.ellipsis),
                          subtitle: Text(timeAgo(n.createdAt)),
                          onTap: () => _open(n),
                        );
                      },
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}
