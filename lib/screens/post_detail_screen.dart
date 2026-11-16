import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import 'post_card.dart';

class PostDetailScreen extends StatefulWidget {
  final int postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  AppPost? _post;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Api.get('posts/${widget.postId}?expand=user.isFollowing,isFavorite');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok && r.data is Map && r.data['post'] != null) _post = AppPost.fromJson(r.data['post']);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
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
