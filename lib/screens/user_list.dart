import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../widgets.dart';
import 'profile_screen.dart';

/// Endless list of users. [loader] returns (users, pageCount) for a page.
typedef UserPageLoader = Future<(List<AppUser>, int)> Function(int page);

class UserList extends StatefulWidget {
  final UserPageLoader loader;
  final String empty;
  const UserList({super.key, required this.loader, this.empty = 'Nobody here yet'});

  @override
  State<UserList> createState() => _UserListState();
}

class _UserListState extends State<UserList> {
  final List<AppUser> _users = [];
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

  Future<void> _load() async {
    if (_loading || _page > _pageCount) return;
    _loading = true;
    final (list, count) = await widget.loader(_page);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _first = true;
      _users.addAll(list);
      _pageCount = count;
      _page += 1;
    });
  }

  Future<void> _follow(AppUser u) async {
    final was = u.isFollowing;
    setState(() => u.isFollowing = !was);
    final r = await Api.post(was ? 'followers/unfollow' : 'followers', {'user_id': u.id});
    if (!r.ok && mounted) setState(() => u.isFollowing = was);
  }

  @override
  Widget build(BuildContext context) {
    if (!_first) return const Center(child: CircularProgressIndicator());
    if (_users.isEmpty) return Center(child: Text(widget.empty));
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView.builder(
          controller: _scroll,
          itemCount: _users.length,
          itemBuilder: (c, i) {
            final u = _users[i];
            return ListTile(
              leading: Avatar(u, size: 44),
              title: Text(u.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: u.username.isEmpty ? null : Text('@${u.username}'),
              trailing: u.isFollowing
                  ? OutlinedButton(onPressed: () => _follow(u), child: const Text('Following'))
                  : FilledButton(onPressed: () => _follow(u), child: const Text('Follow')),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => ProfileScreen(userId: u.id))),
            );
          },
        ),
      ),
    );
  }
}

/// reads {key:{items,_meta}} and maps each item with [pick]
Future<(List<AppUser>, int)> loadUsers(String path, String key, {String? pick}) async {
  final r = await Api.get(path);
  if (!r.ok || r.data is! Map || r.data[key] is! Map) return (<AppUser>[], 1);
  final d = r.data[key] as Map;
  final items = d['items'];
  final list = <AppUser>[];
  if (items is List) {
    for (final e in items) {
      list.add(AppUser.fromJson(pick == null ? e : (e is Map ? e[pick] : null)));
    }
  }
  final meta = d['_meta'];
  final pages = meta is Map ? int.tryParse('${meta['pageCount']}') ?? 1 : 1;
  return (list.where((u) => u.id > 0).toList(), pages);
}

class FollowListScreen extends StatelessWidget {
  final int userId;
  final bool followers;
  const FollowListScreen({super.key, required this.userId, required this.followers});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(followers ? 'Followers' : 'Following')),
      body: UserList(
        empty: followers ? 'No followers yet' : 'Not following anyone yet',
        loader: (page) => followers
            ? loadUsers(
                'followers/my-follower?expand=followerUserDetail.isFollowing&user_id=$userId&page=$page',
                'follower',
                pick: 'followerUserDetail')
            : loadUsers(
                'followers/my-following?expand=followingUserDetail,followingUserDetail.isFollowing&user_id=$userId&page=$page',
                'following',
                pick: 'followingUserDetail'),
      ),
    );
  }
}
