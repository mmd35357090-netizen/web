import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../links.dart';
import 'post_card.dart';

class PostDetailScreen extends StatefulWidget {
  final int postId;
  final String? uniqueId; // link from the main site: /#/p/<unique id>
  const PostDetailScreen({super.key, this.postId = 0, this.uniqueId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  String get _path => widget.uniqueId != null ? '/p/${widget.uniqueId}' : '/post/${widget.postId}';
  AppPost? _post;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    AppLinks.enter(_path);
    _load();
  }

  @override
  void dispose() {
    AppLinks.leave(_path);
    super.dispose();
  }

  Future<void> _load() async {
    final u = widget.uniqueId;
    final r = await Api.get(u != null
        ? 'posts/view-by-unique-id?unique_id=${Uri.encodeQueryComponent(u)}&expand=user.isFollowing,isFavorite'
        : 'posts/${widget.postId}?expand=user.isFollowing,isFavorite');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok && r.data is Map && r.data['post'] != null) _post = AppPost.fromJson(r.data['post']);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post'), actions: [
        IconButton(
          tooltip: 'Share',
          icon: const Icon(Icons.share_outlined),
          onPressed: () => AppLinks.share(context, AppLinks.post(_post?.id ?? widget.postId), title: 'Post'),
        ),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _post == null
              ? const Center(child: Text('This post is not available'))
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: ListView(padding: const EdgeInsets.all(10), children: [PostCard(_post!)]),
                  ),
                ),
    );
  }
}
