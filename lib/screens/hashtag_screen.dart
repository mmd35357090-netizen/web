import 'package:flutter/material.dart';
import '../links.dart';
import 'feed_screen.dart';

class HashtagScreen extends StatelessWidget {
  final String tag;
  const HashtagScreen({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    final clean = tag.startsWith('#') ? tag.substring(1) : tag;
    return Scaffold(
      appBar: AppBar(title: Text('#$clean'), actions: [
        IconButton(
          tooltip: 'Share',
          icon: const Icon(Icons.share_outlined),
          onPressed: () => AppLinks.share(context, AppLinks.tag(clean), title: '#$clean'),
        ),
      ]),
      body: PostList(query: 'is_recent=1&hashtag=${Uri.encodeQueryComponent(clean)}'),
    );
  }
}

class SavedPostsScreen extends StatelessWidget {
  const SavedPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: const PostList(query: 'is_favorite=1'),
    );
  }
}
