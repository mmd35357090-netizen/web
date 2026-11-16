import 'dart:convert';
import 'package:aescryptojs/aescryptojs.dart';
import '../config.dart';
import '../models.dart';

String chatEncrypt(String s) {
  if (s.isEmpty || AppConfig.enableEncryption != 1) return s;
  return encryptAESCryptoJS(s, AppConfig.chatKey);
}

String chatDecrypt(String s) {
  if (s.isEmpty) return '';
  try {
    return decryptAESCryptoJS(s, AppConfig.chatKey);
  } catch (_) {
    return s;
  }
}

int _i(dynamic v, [int d = 0]) {
  if (v == null) return d;
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v.toString()) ?? d;
}

class ChatMsg {
  int id = 0;
  String localId = '';
  int roomId = 0;
  int senderId = 0;
  String senderName = '';
  int type = 1;
  String text = '';
  int createdAt = 0;
  bool sending = false;

  ChatMsg();

  /// reads a message from the REST history, the socket, or a room's lastMessage
  factory ChatMsg.fromJson(dynamic j) {
    final m = ChatMsg();
    if (j is! Map) return m;
    m.id = _i(j['id']);
    m.localId = (j['local_message_id'] ?? j['localMessageId'] ?? '').toString();
    m.roomId = _i(j['room'] ?? j['room_id']);
    m.senderId = _i(j['created_by'] ?? j['createdBy'] ?? j['userId']);
    m.senderName = (j['username'] ?? (j['user'] is Map ? j['user']['username'] : '') ?? '').toString();
    m.type = _i(j['messageType'] ?? j['type'], 1);
    m.createdAt = _i(j['created_at'] ?? j['createdAt']);
    final raw = (j['message'] ?? '').toString().replaceAll('\\', '');
    final encrypted = _i(j['is_encrypted'] ?? j['isEncrypted']) == 1;
    final body = encrypted ? chatDecrypt(raw) : raw;
    m.text = _describe(m.type, body);
    return m;
  }

  static String _describe(int type, String body) {
    try {
      final c = jsonDecode(body);
      if (type == 1 || (c is Map && c['text'] != null && c['messageType'] == 1)) {
        final t = (c is Map ? c['text'] : body).toString();
        return chatDecrypt(t);
      }
      if (type == 9 && c is Map && c['text'] != null) return chatDecrypt(c['text'].toString());
    } catch (_) {
      if (type == 1) return body;
    }
    switch (type) {
      case 2:
        return '📷 Photo';
      case 3:
        return '🎬 Video';
      case 4:
        return '🎤 Voice message';
      case 5:
        return 'GIF';
      case 6:
        return 'Sticker';
      case 7:
        return '👤 Contact';
      case 8:
        return '📍 Location';
      case 11:
        return 'Shared a post';
      case 12:
        return 'Shared a story';
      case 14:
        return 'Shared a profile';
      case 100:
        return '';
      default:
        return type == 1 ? body : 'Message';
    }
  }
}

class ChatRoom {
  int id = 0;
  int type = 1;
  String title = '';
  String? image;
  bool online = false;
  ChatMsg? last;
  int updatedAt = 0;
  AppUser? opponent;

  ChatRoom();

  bool get isGroup => type != 1;

  String get displayName => isGroup ? title : (opponent?.displayName ?? title);

  AppUser get avatarUser {
    if (!isGroup && opponent != null) return opponent!;
    final u = AppUser();
    u.name = title;
    u.picture = image;
    return u;
  }

  factory ChatRoom.fromJson(dynamic j, int myId) {
    final r = ChatRoom();
    if (j is! Map) return r;
    r.id = _i(j['id']);
    r.type = _i(j['type'], 1);
    r.title = (j['title'] ?? '').toString();
    r.image = j['imageUrl']?.toString();
    r.online = _i(j['is_chat_user_online']) == 1;
    r.updatedAt = _i(j['updated_at'] ?? j['created_at']);
    final members = j['chatRoomUser'];
    if (members is List) {
      for (final m in members) {
        if (m is Map) {
          final u = AppUser.fromJson(m['user'] is String ? jsonDecode(m['user']) : m['user']);
          if (u.id != 0 && u.id != myId) {
            r.opponent = u;
            break;
          }
        }
      }
    }
    final lm = j['lastMessage'];
    if (lm is Map) {
      r.last = ChatMsg.fromJson(lm);
      if (r.last!.createdAt > 0) r.updatedAt = r.last!.createdAt;
    }
    return r;
  }
}
