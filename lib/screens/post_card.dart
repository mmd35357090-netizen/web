import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../widgets.dart';
import 'comments_sheet.dart';
import 'hashtag_screen.dart';
import 'profile_screen.dart';
import '../session.dart';

class PostCard extends StatefulWidget {
  final AppPost post;
  const PostCard(this.post, {super.key});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  int _page = 0;
  bool _busy = false;

  AppPost get p => widget.post;

  Future<void> _like() async {
    if (_busy) return;
    _busy = true;
    final was = p.isLiked;
    setState(() {
      p.isLiked = !was;
      p.likes += was ? -1 : 1;
    });
    final r = await Api.post(was ? 'posts/unlike' : 'posts/like', {'post_id': p.id});
    if (!r.ok && mounted) {
      setState(() {
        p.isLiked = was;
        p.likes += was ? 1 : -1;
      });
    }
    _busy = false;
  }

  bool _hidden = false;

  Future<void> _menu(String v) async {
    if (v == 'save') {
      final was = p.isSaved;
      setState(() => p.isSaved = !was);
      final r = await Api.post(was ? 'favorites/remove-favorite' : 'favorites/add-favorite',
          {'reference_id': p.id.toString(), 'type': '3'});
      if (!r.ok && mounted) setState(() => p.isSaved = was);
      if (mounted) toast(context, r.ok ? (was ? 'Removed from saved' : 'Saved') : 'Could not update');
    } else if (v == 'report') {
      final r = await Api.post('posts/report-post', {'post_id': p.id.toString()});
      if (mounted) toast(context, r.ok ? 'Thanks, we will review this post' : 'Could not report');
    } else if (v == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Delete this post?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
          ],
        ),
      );
      if (ok != true) return;
      final r = await Api.delete('posts/${p.id}');
      if (!mounted) return;
      if (r.ok) {
        setState(() => _hidden = true);
      } else {
        toast(context, r.message.isEmpty ? 'Could not delete' : r.message);
      }
    }
  }

  void _openUser() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen(userId: p.user.id)));
  }

  void _comments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => CommentsSheet(post: p, onAdded: () => setState(() => p.comments += 1)),
    );
  }

  Widget _mediaView() {
    if (p.media.isEmpty) return const SizedBox.shrink();
    final first = p.media.first;
    double ratio = 1;
    if (first.width > 0 && first.height > 0) {
      ratio = (first.width / first.height).clamp(0.8, 1.6).toDouble();
    }
    return AspectRatio(
      aspectRatio: ratio,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: p.media.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (c, i) {
              final m = p.media[i];
              final src = m.isVideo ? (m.thumb ?? '') : m.url;
              return Stack(fit: StackFit.expand, children: [
                src.isEmpty
                    ? Container(color: Colors.black12)
                    : netImage(src, width: double.infinity, height: double.infinity),
                if (m.isVideo)
                  const Center(
                    child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 56),
                  ),
              ]);
            },
          ),
          if (p.media.length > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < p.media.length; i++)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page ? Colors.white : Colors.white54,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final mine = Session.me != null && Session.me!.id == p.user.id;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            onTap: _openUser,
            leading: Avatar(p.user, size: 40),
            title: Row(children: [
              Flexible(
                child: Text(p.user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              if (p.user.isVerified)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.verified_rounded, size: 16, color: cs.primary),
                ),
            ]),
            subtitle: Text(timeAgo(p.createdAt)),
            trailing: PopupMenuButton<String>(
              onSelected: _menu,
              itemBuilder: (c) => [
                PopupMenuItem(value: 'save', child: Text(p.isSaved ? 'Remove from saved' : 'Save')),
                if (mine)
                  const PopupMenuItem(value: 'delete', child: Text('Delete'))
                else
                  const PopupMenuItem(value: 'report', child: Text('Report')),
              ],
            ),
          ),
          if (p.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: SelectableText(p.title, style: const TextStyle(fontSize: 15, height: 1.35)),
            ),
          if (p.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(spacing: 8, children: [
                for (final t in p.tags)
                  InkWell(
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => HashtagScreen(tag: t))),
                    child: Text(t, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
                  ),
              ]),
            ),
          _mediaView(),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Row(children: [
              IconButton(
                onPressed: _like,
                icon: Icon(p.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: p.isLiked ? Colors.red : null),
              ),
              Text('${p.likes}'),
              const SizedBox(width: 8),
              if (p.commentsEnabled) ...[
                IconButton(onPressed: _comments, icon: const Icon(Icons.mode_comment_outlined)),
                Text('${p.comments}'),
              ],
              const Spacer(),
              if (p.views > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text('${p.views} views', style: const TextStyle(color: Colors.black54)),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}
