int _i(dynamic v, [int d = 0]) {
  if (v == null) return d;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? d;
}

String _s(dynamic v, [String d = '']) => v == null ? d : v.toString();

class AppUser {
  int id = 0;
  String name = '';
  String username = '';
  String? picture;
  String? cover;
  String bio = '';
  int followers = 0;
  int following = 0;
  int posts = 0;
  int reels = 0;
  bool isFollowing = false;
  bool isVerified = false;

  AppUser();

  factory AppUser.fromJson(dynamic j) {
    final u = AppUser();
    if (j is! Map) return u;
    u.id = _i(j['id']);
    u.name = _s(j['name']);
    u.username = _s(j['username']);
    u.picture = j['picture']?.toString();
    u.cover = j['coverImageUrl']?.toString();
    u.bio = _s(j['bio']);
    u.followers = _i(j['totalFollower']);
    u.following = _i(j['totalFollowing']);
    u.posts = _i(j['totalActivePost'] ?? j['totalPost']);
    u.reels = _i(j['totalReel']);
    u.isFollowing = _i(j['isFollowing']) == 1;
    u.isVerified = _i(j['is_verified']) == 1;
    return u;
  }

  String get displayName => name.isNotEmpty ? name : username;
}

class Media {
  String url = '';
  String? thumb;
  int type = 1; // 1 image, 2 video, 3 audio
  double width = 0;
  double height = 0;

  Media();

  factory Media.fromJson(dynamic j) {
    final m = Media();
    if (j is! Map) return m;
    m.url = _s(j['filenameUrl']);
    m.thumb = j['videoThumbUrl']?.toString();
    m.type = _i(j['media_type'], 1);
    m.width = double.tryParse(_s(j['width'], '0')) ?? 0;
    m.height = double.tryParse(_s(j['height'], '0')) ?? 0;
    return m;
  }

  bool get isVideo => type == 2 || (thumb != null && thumb!.isNotEmpty);
}

class AppPost {
  int id = 0;
  String title = '';
  AppUser user = AppUser();
  int likes = 0;
  int comments = 0;
  int views = 0;
  bool isLiked = false;
  bool commentsEnabled = true;
  int contentType = 1; // 1 text, 2 media, others are special posts
  int createdAt = 0;
  String? shareLink;
  List<Media> media = [];
  List<String> tags = [];

  AppPost();

  factory AppPost.fromJson(dynamic j) {
    final p = AppPost();
    if (j is! Map) return p;
    p.id = _i(j['id']);
    p.title = _s(j['title']);
    p.user = AppUser.fromJson(j['user']);
    p.likes = _i(j['total_like']);
    p.comments = _i(j['total_comment']);
    p.views = _i(j['total_view']);
    p.isLiked = _i(j['is_like']) == 1;
    p.commentsEnabled = j['is_comment_enable'] == null || _i(j['is_comment_enable']) == 1;
    p.contentType = _i(j['post_content_type'], 1);
    p.createdAt = _i(j['created_at']);
    p.shareLink = j['share_link']?.toString();
    final g = j['postGallary'];
    if (g is List) {
      p.media = g.map((x) => Media.fromJson(x)).where((m) => m.url.isNotEmpty).toList();
    }
    final t = j['hashtags'];
    if (t is List) p.tags = t.map((x) => '#$x').toList();
    return p;
  }
}

class AppComment {
  int id = 0;
  String text = '';
  AppUser user = AppUser();
  int createdAt = 0;

  AppComment();

  factory AppComment.fromJson(dynamic j) {
    final c = AppComment();
    if (j is! Map) return c;
    c.id = _i(j['id']);
    c.text = _s(j['comment']);
    c.user = AppUser.fromJson(j['user']);
    c.createdAt = _i(j['created_at']);
    return c;
  }
}

String timeAgo(int epochSeconds) {
  if (epochSeconds <= 0) return '';
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000));
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  if (d.inDays < 365) return '${(d.inDays / 7).floor()}w';
  return '${(d.inDays / 365).floor()}y';
}
