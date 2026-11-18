import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;
import 'screens/hashtag_screen.dart';
import 'screens/post_detail_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets.dart';

@JS('cfgShare')
external JSPromise<JSBoolean> _cfgShare(JSString url, JSString title, JSString text);

/// Shareable links such as  https://app.connecttofriends.com/#/post/12
class AppLinks {
  static String _origin() => '${web.window.location.origin}${web.window.location.pathname}';

  static String post(int id) => '${_origin()}#/post/$id';
  static String user(int id) => '${_origin()}#/user/$id';
  static String tag(String t) => '${_origin()}#/tag/${Uri.encodeComponent(t.replaceFirst('#', ''))}';

  /// Link the person opened the site with (e.g. from a shared post), kept until we can open it.
  static List<String>? pending;

  static void captureInitial() {
    final h = web.window.location.hash; // "#/post/12"
    final parts = h.replaceFirst(RegExp(r'^#/?'), '').split('/').where((e) => e.isNotEmpty).toList();
    if (parts.length >= 2 && const ['post', 'p', 'user', 'tag'].contains(parts[0])) pending = parts;
  }

  /// Opens the screen a shared link points to (after the person is signed in).
  static void openPending(BuildContext context) {
    final p = pending;
    if (p == null) return;
    pending = null;
    final v = Uri.decodeComponent(p[1]);
    final id = int.tryParse(v);
    Widget? w;
    if (p[0] == 'post' && id != null) w = PostDetailScreen(postId: id);
    if (p[0] == 'p') w = PostDetailScreen(uniqueId: v);
    if (p[0] == 'user' && id != null) w = ProfileScreen(userId: id);
    if (p[0] == 'tag') w = HashtagScreen(tag: v);
    if (w != null) Navigator.of(context).push(MaterialPageRoute(builder: (_) => w!));
  }

  // The address bar follows the open screen, so people can copy it from the browser too.
  static final List<String> _stack = [];

  static void _setHash(String h) {
    try {
      web.window.history.replaceState(null, '', h.isEmpty ? web.window.location.pathname : '#$h');
    } catch (_) {}
  }

  static void enter(String path) {
    _stack.add(path);
    _setHash(path);
  }

  static void leave(String path) {
    _stack.remove(path);
    // after the frame, so the screen under it can set its own link first
    WidgetsBinding.instance.addPostFrameCallback((_) => _setHash(_stack.isEmpty ? '' : _stack.last));
  }

  /// Native share sheet where the browser has one (iPhone, Android), otherwise copies the link.
  static Future<void> share(BuildContext context, String url, {String title = '', String text = ''}) async {
    var handled = false;
    try {
      handled = (await _cfgShare(url.toJS, title.toJS, text.toJS).toDart).toDart;
    } catch (_) {}
    if (handled) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) toast(context, 'Link copied');
  }
}
