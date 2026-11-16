import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../widgets.dart';
import 'paged_list.dart';

/// Private account + online status + notification toggles.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _loading = true;
  bool _private = false;
  bool _online = true;
  bool _likes = true;
  bool _comments = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Api.get('users/profile');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok && r.data is Map && r.data['user'] is Map) {
        final j = r.data['user'] as Map;
        _private = '${j['profile_visibility']}' == '2';
        _online = '${j['is_show_online_chat_status']}' == '1';
        _likes = '${j['like_push_notification_status']}' != '0';
        _comments = '${j['comment_push_notification_status']}' != '0';
      }
    });
  }

  Future<void> _call(String path, Map<String, dynamic> body, VoidCallback apply) async {
    final r = await Api.post(path, body);
    if (!mounted) return;
    if (r.ok) {
      setState(apply);
      toast(context, 'Saved');
    } else {
      toast(context, r.message.isEmpty ? 'Could not save' : r.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(children: [
                  SwitchListTile(
                    title: const Text('Private account'),
                    subtitle: const Text('Only approved followers can see your posts'),
                    value: _private,
                    onChanged: (v) => _call('users/profile-visibility', {'profile_visibility': v ? 2 : 1},
                        () => _private = v),
                  ),
                  SwitchListTile(
                    title: const Text('Show online status'),
                    value: _online,
                    onChanged: (v) => _call('users/show-chat-online-status',
                        {'is_show_online_chat_status': v ? '1' : '0'}, () => _online = v),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Like notifications'),
                    value: _likes,
                    onChanged: (v) => _call('users/push-notification-status', {
                      'like_push_notification_status': v ? '1' : '0',
                      'comment_push_notification_status': _comments ? '1' : '0',
                    }, () => _likes = v),
                  ),
                  SwitchListTile(
                    title: const Text('Comment notifications'),
                    value: _comments,
                    onChanged: (v) => _call('users/push-notification-status', {
                      'like_push_notification_status': _likes ? '1' : '0',
                      'comment_push_notification_status': v ? '1' : '0',
                    }, () => _comments = v),
                  ),
                ]),
              ),
            ),
    );
  }
}

class FollowRequestsScreen extends StatefulWidget {
  const FollowRequestsScreen({super.key});

  @override
  State<FollowRequestsScreen> createState() => _FollowRequestsScreenState();
}

class _FollowRequestsScreenState extends State<FollowRequestsScreen> {
  int _k = 0;

  Future<void> _act(String path, int uid) async {
    final r = await Api.post(path, {'user_id': '$uid'});
    if (!mounted) return;
    if (r.ok) {
      setState(() => _k++);
    } else {
      toast(context, r.message.isEmpty ? 'Failed' : r.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Follow requests')),
      body: PagedList(
        key: ValueKey(_k),
        path: 'followers/my-received-following-request?expand=followerUserDetail',
        listKey: 'followingRequest',
        empty: 'No pending requests',
        builder: (c, it) {
          final d = it['followerUserDetail'];
          if (d == null) return const SizedBox.shrink();
          final u = AppUser.fromJson(d);
          return Card(
            elevation: 0,
            child: ListTile(
              leading: Avatar(u),
              title: Text(u.displayName),
              subtitle: Text('@${u.username}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                    tooltip: 'Decline',
                    icon: const Icon(Icons.close_rounded, color: Colors.red),
                    onPressed: () => _act('followers/cancel-request', u.id)),
                IconButton(
                    tooltip: 'Accept',
                    icon: const Icon(Icons.check_rounded, color: Colors.green),
                    onPressed: () => _act('followers/accept-request', u.id)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FAQ')),
      body: PagedList(
        path: 'faqs?',
        listKey: 'faq',
        empty: 'No FAQ yet',
        builder: (c, f) => Card(
          elevation: 0,
          child: ExpansionTile(
            title: Text(str(f['question']), style: const TextStyle(fontWeight: FontWeight.w600)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(str(f['answer']))],
          ),
        ),
      ),
    );
  }
}
