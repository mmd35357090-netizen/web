/// Keeps the real server address out of the browser.
///
/// The site talks to  https://<this site>/api/...  and  /socket.io/...  and the web server (Apache) forwards
/// those to the backend. Addresses the server sends back (pictures, videos) are rewritten to this site too,
/// and turned back to the real address when we send them to other people (chat), so the Android app
/// keeps working with its normal addresses.
class Endpoints {
  /// Real backend host, as the server writes it in its replies.
  static const String backendHost = 'https://c2f.connecttofriends.com';

  /// Older address the server may still write (kept working until the Android app moves over).
  static const String oldBackendHost = 'https://facehub.sbehf.com';

  static String get origin => Uri.base.origin;

  /// "/api/web/v1/" -> "https://this-site/api/web/v1/". A full address is left alone.
  static String resolve(String u) => u.startsWith('/') ? '$origin$u' : u;

  static bool get _active => !origin.startsWith(backendHost);

  /// Server reply -> what the browser sees.
  static String hide(String s) {
    if (!_active) return s;
    var out = s;
    for (final h in const [backendHost, oldBackendHost]) {
      out = out.replaceAll(h, origin).replaceAll(h.replaceAll('/', r'\/'), origin.replaceAll('/', r'\/'));
    }
    return out;
  }

  /// Address seen by the browser -> real address (used when we send it to Android users).
  static String restore(String s) => _active ? s.replaceAll(origin, backendHost) : s;
}
