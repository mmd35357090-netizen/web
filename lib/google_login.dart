import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'config.dart';

@JS('cfgGoogleInit')
external void _gInit(JSString clientId, JSFunction cb);

@JS('cfgGoogleRender')
external void _gRender(web.HTMLElement el, JSNumber width);

bool _registered = false;

/// Claims we need from the Google ID token (the server checks the signature itself).
Map<String, dynamic>? decodeGoogleToken(String jwt) {
  try {
    final parts = jwt.split('.');
    if (parts.length != 3) return null;
    final m = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    return m is Map<String, dynamic> ? m : null;
  } catch (_) {
    return null;
  }
}

/// Official Google button (rendered by Google). [onCredential] gets the signed ID token.
class GoogleButton extends StatefulWidget {
  final void Function(String idToken) onCredential;
  const GoogleButton({super.key, required this.onCredential});

  @override
  State<GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<GoogleButton> {
  @override
  void initState() {
    super.initState();
    _gInit(
      AppConfig.googleClientId.toJS,
      ((JSString c) => widget.onCredential(c.toDart)).toJS,
    );
    if (!_registered) {
      _registered = true;
      ui_web.platformViewRegistry.registerViewFactory('cfg-google-btn', (int id) {
        final el = web.document.createElement('div') as web.HTMLElement;
        el.style.width = '100%';
        _gRender(el, 300.toJS);
        return el;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 44,
      width: 300,
      child: HtmlElementView(viewType: 'cfg-google-btn'),
    );
  }
}
