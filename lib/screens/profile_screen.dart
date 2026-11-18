import 'package:flutter/material.dart';
import '../links.dart';
import '../api.dart';
import '../models.dart';
import '../widgets.dart';
import 'feed_screen.dart';
import 'user_list.dart';
import 'chat_list_screen.dart';
import 'settings_screen.dart';
import 'highlights_bar.dart';

/// userId == null -> the logged in user's own profile
class ProfileScreen extends StatefulWidget {
  final int? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AppUser? _user;
  bool _loading = true;
  bool _busy = false;
  String _error = '';

  bool get _own => widget.userId == null;

  @override
  void initState() {
    super.initState();
    if (!_own) AppLinks.enter('/user/${widget.userId}');
    _load();
  }

  @override
  void dispose() {
    if (!_own) AppLinks.leave('/user/${widget.userId}');
    super.dispose();
  }

  Future<void> _load() async {
    final path = _own
        ? 'users/profile?expand=totalFollowing,totalFollower,totalActivePost,totalReel'
        : 'users/${widget.userId}?expand=isFollowing,totalFollowing,totalFollower,totalPost,totalReel';
    final r = await Api.get(path);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok && r.data is Map && r.data['user'] != null) {
        _user = AppUser.fromJson(r.data['user']);
      } else {
        _error = r.message.isEmpty ? 'Could not load profile' : r.message;
      }
    });
  }

  Future<void> _toggleFollow() async {
    final u = _user;
    if (u == null || _busy) return;
    _busy = true;
    final was = u.isFollowing;
    setState(() {
      u.isFollowing = !was;
      u.followers += was ? -1 : 1;
    });
    final r = await Api.post(was ? 'followers/unfollow' : 'followers', {'user_id': u.id});
    if (!r.ok && mounted) {
      setState(() {
        u.isFollowing = was;
        u.followers += was ? 1 : -1;
      });
    }
    _busy = false;
  }

  Widget _stat(String label, int v, {VoidCallback? onTap}) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Column(children: [
          Text('$v', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _user == null
            ? Center(child: Text(_error))
            : _content(_user!);
    if (_own) return body;
    return Scaffold(appBar: AppBar(title: Text(_user?.displayName ?? '')), body: body);
  }

  Future<void> _userAction(String v, AppUser u) async {
    if (v == 'block') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Block ${u.displayName}?'),
          content: const Text('They will no longer be able to find you or message you.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Block')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      final r = await Api.post('blocked-users', {'blocked_user_id': '${u.id}'});
      if (!mounted) return;
      if (r.ok) {
        toast(context, 'User blocked');
        Navigator.of(context).maybePop();
      } else {
        toast(context, r.message.isEmpty ? 'Could not block' : r.message);
      }
    } else {
      final r = await Api.post('users/report-user', {'report_to_user_id': '${u.id}'});
      if (mounted) toast(context, r.ok ? 'Thanks, we will review this user' : 'Could not report');
    }
  }

  void _openList(AppUser u, bool followers) {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => FollowListScreen(userId: u.id, followers: followers)));
  }

  Widget _content(AppUser u) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(children: [
          if (!_own)
            Align(
              alignment: Alignment.centerRight,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'Share profile',
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () => AppLinks.share(context, AppLinks.user(u.id), title: u.displayName),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => _userAction(v, u),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'report', child: Text('Report user')),
                    PopupMenuItem(value: 'block', child: Text('Block user')),
                  ],
                ),
              ]),
            ),
          if (_own)
            Align(
              alignment: Alignment.centerRight,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'Share my profile',
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () => AppLinks.share(context, AppLinks.user(u.id), title: u.displayName),
                ),
                IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () async {
                  await Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  if (mounted) _load();
                },
              ),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(children: [
              Avatar(u, size: 88),
              const SizedBox(height: 10),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(u.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                if (u.isVerified)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(Icons.verified_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                  ),
              ]),
              if (u.username.isNotEmpty)
                Text('@${u.username}', style: const TextStyle(color: Colors.black54)),
              if (u.bio.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(u.bio, textAlign: TextAlign.center),
                ),
              const SizedBox(height: 14),
              Row(children: [
                _stat('Posts', u.posts),
                _stat('Followers', u.followers, onTap: () => _openList(u, true)),
                _stat('Following', u.following, onTap: () => _openList(u, false)),
              ]),
              if (!_own) ...[
                const SizedBox(height: 12),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: 140,
                    child: u.isFollowing
                        ? OutlinedButton(onPressed: _toggleFollow, child: const Text('Following'))
                        : FilledButton(onPressed: _toggleFollow, child: const Text('Follow')),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 140,
                    child: OutlinedButton.icon(
                      onPressed: () => openChatWith(context, u),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                      label: const Text('Message'),
                    ),
                  ),
                ]),
              ],
            ]),
          ),
          HighlightsBar(key: ValueKey(u.id), userId: u.id, own: _own),
          const Divider(height: 1),
          Expanded(child: PostList(query: 'user_id=${u.id}')),
        ]),
      ),
    );
  }
}
