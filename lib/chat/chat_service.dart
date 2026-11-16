import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config.dart';
import '../session.dart';
import 'chat_models.dart';

/// One socket connection for the whole web app.
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  io.Socket? _socket;
  final _messages = StreamController<ChatMsg>.broadcast();
  final _confirms = StreamController<Map<String, dynamic>>.broadcast();
  final _typing = StreamController<Map<String, dynamic>>.broadcast();
  final _online = StreamController<Map<String, dynamic>>.broadcast();
  final List<List<dynamic>> _queue = [];

  Stream<ChatMsg> get messages => _messages.stream;
  Stream<Map<String, dynamic>> get confirms => _confirms.stream;
  Stream<Map<String, dynamic>> get typing => _typing.stream;
  Stream<Map<String, dynamic>> get online => _online.stream;
  bool get connected => _socket?.connected == true;

  Map<String, dynamic> _map(dynamic d) => d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};

  Future<void> connect() async {
    if (_socket != null) return;
    final me = await Session.load();
    if (me == null) return;
    final s = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder().setTransports(['websocket', 'polling']).disableAutoConnect().build(),
    );
    _socket = s;
    s.on('connect', (_) {
      s.emit('login', {'userId': me.id, 'username': me.username});
      for (final q in _queue) {
        s.emit(q[0] as String, q[1]);
      }
      _queue.clear();
    });
    s.on('sendMessage', (d) {
      if (d is Map) _messages.add(ChatMsg.fromJson(d));
    });
    s.on('updateMessageCurrentStatus', (d) => _confirms.add(_map(d)));
    s.on('typing', (d) => _typing.add(_map(d)));
    s.on('userOnline', (d) => _online.add({..._map(d), 'online': true}));
    s.on('userOffline', (d) => _online.add({..._map(d), 'online': false}));
    s.connect();
  }

  void emit(String event, Map<String, dynamic> data) {
    final s = _socket;
    if (s != null && s.connected) {
      s.emit(event, data);
    } else {
      _queue.add([event, data]);
      s?.connect();
    }
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _queue.clear();
  }
}
