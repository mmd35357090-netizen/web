/// Remembers the share address the server made for each post
/// (https://connecttofriends.com/<username>/p|video|reel/<id>).
///
/// That address shows a preview (picture + text of the post) in WhatsApp / Messenger / Telegram,
/// opens the mobile app for people who have it, and sends everybody else to the website.
/// Filled when a post is read from the server; the share buttons ask for it here.
class ShareRegistry {
  static final Map<int, String> _links = {};

  static void remember(int id, String? link) {
    if (id <= 0 || link == null) return;
    final l = link.trim();
    if (l.isEmpty || !l.startsWith('http')) return;
    if (_links.length > 3000) _links.clear();
    _links[id] = l;
  }

  static String? of(int id) => _links[id];
}
