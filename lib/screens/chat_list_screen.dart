import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../chat/chat_models.dart';
import '../chat/chat_service.dart';
import '../models.dart';
import '../session.dart';
import '../widgets.dart';
import 'chat_screen.dart';
import 'new_group_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ChatRoom> _rooms = [];
  bool _loading = true;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = ChatService.instance.messages.listen((m) {
      // a new message arrived: refresh the order and last message
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final me = await Session.load();
    final r = await Api.get(
        'chats/room?expand=createdByUser,chatRoomUser,chatRoomUser.user,lastMessage');
    if (!mounted) return;
    setState(() {
      _loading = false;
      final list = r.data is Map ? r.data['room'] : null;
      if (r.ok && list is List) {
        _rooms = list.map((e) => ChatRoom.fromJson(e, me?.id ?? 0)).where((x) => x.id > 0).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(children: [
              const Expanded(
                child: Text('Messages', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const NewGroupScreen()));
                  _load(silent: true);
                },
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('New group'),
              ),
            ]),
          ),
          Expanded(
            child: _rooms.isEmpty
                ? const Center(child: Text('No chats yet. Open a profile and tap Message.'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      itemCount: _rooms.length,
                      itemBuilder: (c, i) {
                        final r = _rooms[i];
                        final preview = r.last == null ? '' : r.last!.text;
                        return ListTile(
                          leading: Avatar(r.avatarUser, size: 46),
                          title: Text(r.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Text(timeAgo(r.updatedAt),
                              style: const TextStyle(fontSize: 12, color: Colors.black45)),
                          onTap: () async {
                            await Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ChatScreen(roomId: r.id, title: r.displayName, user: r.avatarUser, isGroup: r.isGroup)));
                            _load(silent: true);
                          },
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

/// starts (or opens) a one-to-one chat with a user
Future<void> openChatWith(BuildContext context, AppUser u) async {
  final r = await Api.post('chats/create-room', {'receiver_id': u.id.toString(), 'type': '1'});
  if (!context.mounted) return;
  final id = r.data is Map ? int.tryParse('${r.data['room_id']}') : null;
  if (!r.ok || id == null) {
    toast(context, r.message.isEmpty ? 'Could not open chat' : r.message);
    return;
  }
  Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(roomId: id, title: u.displayName, user: u)));
}
