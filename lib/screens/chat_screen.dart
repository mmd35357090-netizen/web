import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../api.dart';
import '../chat/chat_models.dart';
import '../chat/chat_service.dart';
import '../config.dart';
import '../models.dart';
import '../session.dart';
import '../widgets.dart';

class ChatScreen extends StatefulWidget {
  final int roomId;
  final String title;
  final AppUser user;
  const ChatScreen({super.key, required this.roomId, required this.title, required this.user});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMsg> _msgs = [];
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _subs = <StreamSubscription>[];
  int _myId = 0;
  bool _loading = true;
  bool _more = true;
  bool _loadingOlder = false;
  bool _typing = false;
  Timer? _typingTimer;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final me = await Session.load();
    _myId = me?.id ?? 0;
    final svc = ChatService.instance;
    await svc.connect();
    _subs.add(svc.messages.listen(_onMessage));
    _subs.add(svc.confirms.listen(_onConfirm));
    _subs.add(svc.typing.listen((d) {
      if ('${d['room']}' == '${widget.roomId}') {
        setState(() => _typing = true);
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _typing = false);
        });
      }
    }));
    await _loadHistory(first: true);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _typingTimer?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadHistory({bool first = false}) async {
    if (_loadingOlder) return;
    _loadingOlder = true;
    final oldest = _msgs.where((m) => m.id > 0).fold<int>(0, (a, m) => a == 0 || m.id < a ? m.id : a);
    final r = await Api.get(
        'chats/chat-message?expand=chatMessageUser,user&room_id=${widget.roomId}&last_message_id=${first ? 0 : oldest}');
    if (!mounted) return;
    final d = r.data is Map ? r.data['chatMessage'] : null;
    final items = d is Map ? d['items'] : null;
    setState(() {
      _loading = false;
      _loadingOlder = false;
      if (r.ok && items is List) {
        final got = items.map((e) => ChatMsg.fromJson(e)).where((m) => m.id > 0 && m.type != 100).toList();
        final have = _msgs.map((m) => m.id).toSet();
        for (final m in got) {
          if (!have.contains(m.id)) _msgs.add(m);
        }
        _msgs.sort((a, b) => a.id == 0 || b.id == 0 ? a.createdAt.compareTo(b.createdAt) : a.id.compareTo(b.id));
        _more = got.length >= 10;
      } else {
        _more = false;
      }
    });
    if (first) _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _onMessage(ChatMsg m) {
    if (m.roomId != widget.roomId || m.type == 100) return;
    // our own message coming back
    if (m.senderId == _myId && m.localId.isNotEmpty && _msgs.any((x) => x.localId == m.localId)) return;
    if (m.id > 0 && _msgs.any((x) => x.id == m.id)) return;
    setState(() => _msgs.add(m));
    _toBottom();
    if (m.id > 0 && m.senderId != _myId) {
      ChatService.instance.emit('readMessage', {'id': m.id, 'room': m.roomId});
    }
  }

  void _onConfirm(Map<String, dynamic> d) {
    final local = (d['localMessageId'] ?? d['local_message_id'] ?? '').toString();
    if (local.isEmpty) return;
    final idx = _msgs.indexWhere((x) => x.localId == local);
    if (idx >= 0) {
      setState(() {
        _msgs[idx].sending = false;
        final id = int.tryParse('${d['id']}');
        if (id != null) _msgs[idx].id = id;
      });
    }
  }

  void _changed(String _) {
    final now = DateTime.now();
    if (now.difference(_lastTypingSent).inSeconds >= 2) {
      _lastTypingSent = now;
      ChatService.instance.emit('typing', {'room': widget.roomId});
    }
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final localId = '${DateTime.now().microsecondsSinceEpoch}${_myId}';
    final nowSec = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    final content = jsonEncode({'messageType': 1, 'text': chatEncrypt(text)});
    ChatService.instance.emit('sendMessage', {
      'userId': _myId,
      'localMessageId': localId,
      'is_encrypted': AppConfig.enableEncryption,
      'messageType': 1,
      'message': chatEncrypt(content),
      'replied_on_message': null,
      'chat_version': AppConfig.chatVersion,
      'room': widget.roomId,
      'created_by': _myId,
      'created_at': nowSec,
    });
    final m = ChatMsg()
      ..localId = localId
      ..roomId = widget.roomId
      ..senderId = _myId
      ..type = 1
      ..text = text
      ..createdAt = nowSec
      ..sending = true;
    setState(() => _msgs.add(m));
    _ctrl.clear();
    _toBottom();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          Avatar(widget.user, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
              if (_typing) Text('typing...', style: TextStyle(fontSize: 12, color: cs.primary)),
            ]),
          ),
        ]),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: _msgs.length + 1,
                      itemBuilder: (c, i) {
                        if (i == 0) {
                          return _more
                              ? Center(
                                  child: TextButton(
                                      onPressed: () => _loadHistory(), child: const Text('Load earlier messages')))
                              : const SizedBox.shrink();
                        }
                        final m = _msgs[i - 1];
                        final mine = m.senderId == _myId;
                        return Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            constraints: const BoxConstraints(maxWidth: 460),
                            decoration: BoxDecoration(
                              color: mine ? cs.primary : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SelectableText(m.text,
                                    style: TextStyle(color: mine ? Colors.white : Colors.black87)),
                                const SizedBox(height: 2),
                                Text(m.sending ? 'sending...' : timeAgo(m.createdAt),
                                    style: TextStyle(
                                        fontSize: 10, color: mine ? Colors.white70 : Colors.black45)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      onChanged: _changed,
                      onSubmitted: (_) => _send(),
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: 'Message',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: _send, icon: const Icon(Icons.send_rounded)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
