/// Keeps the real server address out of the browser.
///
/// The site talks to  https://<this site>/api/...  and  /socket.io/...  and the web server (Apache) forwards
/// those to the backend. Addresses the server sends back (pictures, videos) are rewritten to this site too,
/// and turned back to the real address when we send them to other people (chat), so the Android app
/// keeps working with its normal addresses.
class Endpoints {
  /// Real backend host, as the server writes it in its replies.
  static const String backendHost = 'https://c2f.connecttofriends.com';

  static String get origin => Uri.base.origin;

  /// "/api/web/v1/" -> "https://this-site/api/web/v1/". A full address is left alone.
  static String resolve(String u) => u.startsWith('/') ? '$origin$u' : u;

  static bool get _active => !origin.startsWith(backendHost);

  /// Server reply -> what the browser sees.
  static String hide(String s) {
    if (!_active) return s;
    return s
        .replaceAll(backendHost, origin)
        .replaceAll(backendHost.replaceAll('/', r'\/'), origin.replaceAll('/', r'\/'));
  }

  /// Address seen by the browser -> real address (used when we send it to Android users).
  static String restore(String s) => _active ? s.replaceAll(origin, backendHost) : s;
}
