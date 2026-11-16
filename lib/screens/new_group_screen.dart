import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../session.dart';
import '../chat/chat_service.dart';
import '../widgets.dart';
import 'chat_screen.dart';
import 'paged_list.dart';

class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final Map<int, AppUser> _picked = {};
  bool _public = false;
  bool _busy = false;
  int _meId = 0;

  @override
  void initState() {
    super.initState();
    Session.load().then((u) {
      if (mounted) setState(() => _meId = u?.id ?? -1);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      toast(context, 'Enter a group name');
      return;
    }
    if (_picked.isEmpty && !_public) {
      toast(context, 'Pick at least one member');
      return;
    }
    setState(() => _busy = true);
    final me = await Session.load();
    final r = await Api.post('chats/create-room', {
      'type': _public ? '3' : '2',
      'receiver_id': '',
      'title': title,
      'image': '',
      'description': _desc.text.trim(),
    });
    if (!mounted) return;
    final id = r.data is Map ? int.tryParse('${r.data['room_id']}') : null;
    if (!r.ok || id == null || me == null) {
      setState(() => _busy = false);
      toast(context, r.message.isEmpty ? 'Could not create group' : r.message);
      return;
    }
    await ChatService.instance.connect();
    final ids = [me.id, ..._picked.keys].join(',');
    ChatService.instance.emit('addUser', {'userId': ids, 'room': id});
    final g = AppUser()..name = title;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ChatScreen(roomId: id, title: title, user: g, isGroup: true)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New group'),
        actions: [
          TextButton(onPressed: _busy ? null : _create, child: const Text('Create')),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(children: [
                TextField(controller: _title, decoration: const InputDecoration(labelText: 'Group name', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description (optional)', isDense: true)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Public group'),
                  subtitle: const Text('Anyone can find and join'),
                  value: _public,
                  onChanged: (v) => setState(() => _public = v),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Members (${_picked.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            Expanded(
              child: _meId == 0
                  ? const Center(child: CircularProgressIndicator())
                  : PagedList(
                path: 'followers/my-following?expand=followingUserDetail&user_id=$_meId',
                listKey: 'following',
                empty: 'Follow people to add them to a group',
                builder: (c, it) {
                  final d = it['followingUserDetail'];
                  if (d == null) return const SizedBox.shrink();
                  final u = AppUser.fromJson(d);
                  return CheckboxListTile(
                    secondary: Avatar(u),
                    title: Text(u.displayName),
                    subtitle: Text('@${u.username}'),
                    value: _picked.containsKey(u.id),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _picked[u.id] = u;
                      } else {
                        _picked.remove(u.id);
                      }
                    }),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
