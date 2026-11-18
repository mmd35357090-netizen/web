import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import '../api.dart';
import '../chat/chat_models.dart';
import '../chat/chat_service.dart';
import '../config.dart';
import '../endpoints.dart';
import '../models.dart';
import '../session.dart';
import '../widgets.dart';

class ChatScreen extends StatefulWidget {
  final int roomId;
  final String title;
  final AppUser user;
  final bool isGroup;
  const ChatScreen(
      {super.key, required this.roomId, required this.title, required this.user, this.isGroup = false});

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
    _subs.add(svc.deletes.listen((d) {
      if ('${d['room']}' != '${widget.roomId}') return;
      final id = int.tryParse('${d['id']}');
      if (id == null) return;
      final i = _msgs.indexWhere((x) => x.id == id);
      if (i >= 0 && mounted) setState(() => _msgs[i].deleted = true);
    }));
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

  bool _uploading = false;

  Future<void> _onLongPress(ChatMsg m) async {
    if (m.id <= 0 || m.deleted) return;
    final mine = m.senderId == _myId;
    final choice = await showModalBottomSheet<int>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: const Text('Delete for me'),
            onTap: () => Navigator.pop(c, 1),
          ),
          if (mine)
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
              title: const Text('Delete for everyone', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(c, 2),
            ),
        ]),
      ),
    );
    if (choice == null) return;
    ChatService.instance.emit('deleteMessage', {'id': m.id, 'room': widget.roomId, 'deleteScope': choice});
    if (!mounted) return;
    setState(() {
      if (choice == 1) {
        _msgs.removeWhere((x) => x.id == m.id);
      } else {
        m.deleted = true;
      }
    });
  }

  String _mime(String name) {
    switch (name.split('.').last.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _attach() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'mov', 'webm'],
      withData: true,
    );
    if (res == null || res.files.isEmpty || !mounted) return;
    final f = res.files.first;
    final Uint8List? bytes = f.bytes;
    if (bytes == null) return;
    final ext = f.name.split('.').last.toLowerCase();
    final isVideo = ext == 'mp4' || ext == 'mov' || ext == 'webm';
    if (bytes.length > (isVideo ? 50 : 15) * 1024 * 1024) {
      toast(context, 'File is too large (max ${isVideo ? 50 : 15} MB)');
      return;
    }
    setState(() => _uploading = true);
    final r = await Api.upload(f.name, bytes, _mime(f.name), type: '5');
    String? url;
    if (r.ok && r.data is Map && r.data['files'] is List && (r.data['files'] as List).isNotEmpty) {
      final first = (r.data['files'] as List).first;
      if (first is Map && first['isProhabited'] != true) url = first['fileUrl']?.toString();
    }
    if (!mounted) return;
    setState(() => _uploading = false);
    if (url == null || url.isEmpty) {
      toast(context, r.message.isNotEmpty ? r.message : 'Could not upload file');
      return;
    }
    final type = isVideo ? 3 : 2;
    final localId = '${DateTime.now().microsecondsSinceEpoch}$_myId';
    final nowSec = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    final content = jsonEncode(isVideo
        ? {'messageType': 3, 'video': Endpoints.restore(url), 'image': ''}
        : {'messageType': 2, 'image': Endpoints.restore(url)});
    ChatService.instance.emit('sendMessage', {
      'userId': _myId,
      'localMessageId': localId,
      'is_encrypted': AppConfig.enableEncryption,
      'messageType': type,
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
      ..type = type
      ..text = isVideo ? '🎬 Video' : '📷 Photo'
      ..media = url
      ..createdAt = nowSec
      ..sending = true;
    setState(() => _msgs.add(m));
    _toBottom();
  }

  Widget _body(ChatMsg m, bool mine) {
    final color = TextStyle(color: mine ? Colors.white : Colors.black87);
    if (m.deleted) {
      return Text('This message was deleted',
          style: TextStyle(fontStyle: FontStyle.italic, color: mine ? Colors.white70 : Colors.black45));
    }
    if ((m.type == 2 || m.type == 5) && m.media.isNotEmpty) {
      return GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.black,
            child: InteractiveViewer(child: netImage(m.media, fit: BoxFit.contain)),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260, maxHeight: 320),
            child: netImage(m.media, fit: BoxFit.cover),
          ),
        ),
      );
    }
    if (m.type == 3 && m.media.isNotEmpty) {
      return InkWell(
        onTap: () => showDialog(context: context, builder: (_) => _VideoDialog(url: m.media)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.play_circle_fill_rounded, color: mine ? Colors.white : Colors.black87),
          const SizedBox(width: 6),
          Text('Play video', style: color),
        ]),
      );
    }
    return SelectableText(m.text, style: color);
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
                          child: GestureDetector(
                            onLongPress: () => _onLongPress(m),
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
                                if (widget.isGroup && !mine && m.senderName.isNotEmpty)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(m.senderName,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Theme.of(context).colorScheme.primary)),
                                  ),
                                _body(m, mine),
                                const SizedBox(height: 2),
                                Text(m.sending ? 'sending...' : timeAgo(m.createdAt),
                                    style: TextStyle(
                                        fontSize: 10, color: mine ? Colors.white70 : Colors.black45)),
                              ],
                            ),
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
                  _uploading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                      : IconButton(
                          tooltip: 'Photo / video',
                          onPressed: _attach,
                          icon: const Icon(Icons.attach_file_rounded)),
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


class _VideoDialog extends StatefulWidget {
  final String url;
  const _VideoDialog({required this.url});

  @override
  State<_VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<_VideoDialog> {
  late final VideoPlayerController _c;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _c.initialize().then((_) {
      if (mounted) {
        setState(() => _ready = true);
        _c.play();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: _ready
          ? GestureDetector(
              onTap: () => setState(() => _c.value.isPlaying ? _c.pause() : _c.play()),
              child: AspectRatio(aspectRatio: _c.value.aspectRatio, child: VideoPlayer(_c)),
            )
          : const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
    );
  }
}
