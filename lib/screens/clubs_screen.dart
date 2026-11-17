import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets.dart';
import 'create_club_screen.dart';
import 'feed_screen.dart';

class ClubItem {
  int id = 0;
  String name = '';
  String? image;
  String desc = '';
  int members = 0;
  bool joined = false;
  bool requested = false;
  bool requestBased = false;

  ClubItem();

  factory ClubItem.fromJson(dynamic j) {
    final c = ClubItem();
    if (j is! Map) return c;
    c.id = int.tryParse('${j['id']}') ?? 0;
    c.name = (j['name'] ?? '').toString();
    c.image = j['imageUrl']?.toString();
    c.desc = (j['description'] ?? '').toString();
    c.members = int.tryParse('${j['totalJoinedUser']}') ?? 0;
    c.joined = '${j['is_joined']}' == '1';
    c.requested = '${j['is_join_requested']}' == '1';
    c.requestBased = '${j['is_request_based']}' == '1';
    return c;
  }
}

class ClubsScreen extends StatefulWidget {
  const ClubsScreen({super.key});

  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _search = TextEditingController();
  Timer? _debounce;
  String _text = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clubs'),
        actions: [
          IconButton(
            tooltip: 'Create club',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () async {
              final ok = await Navigator.of(context)
                  .push<bool>(MaterialPageRoute(builder: (_) => const CreateClubScreen()));
              if (ok == true && mounted) setState(() {});
            },
          ),
        ],
        bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Discover'), Tab(text: 'My clubs')]),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: TextField(
            controller: _search,
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 450), () {
                if (mounted) setState(() => _text = v.trim());
              });
            },
            decoration: InputDecoration(
              hintText: 'Search clubs',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            _ClubList(key: ValueKey('all$_text'), query: 'name=${Uri.encodeQueryComponent(_text)}'),
            _ClubList(key: ValueKey('my$_text'), query: 'name=${Uri.encodeQueryComponent(_text)}&my_joined_club=1'),
          ]),
        ),
      ]),
    );
  }
}

class _ClubList extends StatefulWidget {
  final String query;
  const _ClubList({super.key, required this.query});

  @override
  State<_ClubList> createState() => _ClubListState();
}

class _ClubListState extends State<_ClubList> {
  final List<ClubItem> _items = [];
  final _scroll = ScrollController();
  int _page = 1;
  int _pages = 1;
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

  Future<void> _load() async {
    if (_loading || _page > _pages) return;
    _loading = true;
    final r = await Api.get('clubs?expand=createdByUser,totalJoinedUser&${widget.query}&page=$_page');
    if (!mounted) return;
    setState(() {
      _loading = false;
      _first = true;
      final d = r.data is Map ? r.data['club'] : null;
      if (r.ok && d is Map) {
        final items = d['items'];
        if (items is List) _items.addAll(items.map((e) => ClubItem.fromJson(e)).where((c) => c.id > 0));
        final meta = d['_meta'];
        if (meta is Map) _pages = int.tryParse('${meta['pageCount']}') ?? _page;
        _page += 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_first) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const Center(child: Text('No clubs found'));
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView.builder(
          controller: _scroll,
          itemCount: _items.length,
          itemBuilder: (c, i) {
            final club = _items[i];
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: club.image == null || club.image!.isEmpty
                      ? const ColoredBox(color: Colors.black12, child: Icon(Icons.groups_rounded))
                      : netImage(club.image!, width: 52, height: 52),
                ),
              ),
              title: Text(club.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${club.members} members${club.joined ? ' • Joined' : ''}'),
              onTap: () async {
                await Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => ClubDetailScreen(club: club)));
                if (mounted) setState(() {});
              },
            );
          },
        ),
      ),
    );
  }
}

class ClubDetailScreen extends StatefulWidget {
  final ClubItem club;
  const ClubDetailScreen({super.key, required this.club});

  @override
  State<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends State<ClubDetailScreen> {
  bool _busy = false;
  ClubItem get c => widget.club;

  Future<void> _toggle() async {
    setState(() => _busy = true);
    final leaving = c.joined;
    final path = leaving ? 'clubs/left' : (c.requestBased ? 'clubs/join-request' : 'clubs/join');
    final r = await Api.post(path, leaving || !c.requestBased ? {'id': c.id.toString()} : {'club_id': c.id.toString()});
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.ok) {
        if (leaving) {
          c.joined = false;
          c.members = c.members > 0 ? c.members - 1 : 0;
        } else if (c.requestBased) {
          c.requested = true;
        } else {
          c.joined = true;
          c.members += 1;
        }
      }
    });
    if (!r.ok) toast(context, r.message.isEmpty ? 'Could not update' : r.message);
  }

  @override
  Widget build(BuildContext context) {
    final label = c.joined ? 'Leave club' : (c.requested ? 'Request sent' : (c.requestBased ? 'Request to join' : 'Join club'));
    return Scaffold(
      appBar: AppBar(title: Text(c.name)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(children: [
            if (c.image != null && c.image!.isNotEmpty)
              SizedBox(height: 180, width: double.infinity, child: netImage(c.image!, width: double.infinity, height: 180)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Text('${c.members} members', style: const TextStyle(color: Colors.black54)),
                if (c.desc.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(c.desc)),
                const SizedBox(height: 12),
                c.joined
                    ? OutlinedButton(onPressed: _busy ? null : _toggle, child: Text(label))
                    : FilledButton(onPressed: (_busy || c.requested) ? null : _toggle, child: Text(label)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(child: PostList(query: 'is_recent=1&club_id=${c.id}')),
          ]),
        ),
      ),
    );
  }
}
