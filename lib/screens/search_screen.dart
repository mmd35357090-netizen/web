import 'dart:async';
import 'package:flutter/material.dart';
import 'user_list.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _text = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _changed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _text = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: TextField(
              controller: _ctrl,
              onChanged: _changed,
              decoration: InputDecoration(
                hintText: 'Search people',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      Expanded(
        child: UserList(
          key: ValueKey(_text),
          empty: 'No people found',
          loader: (page) => loadUsers(
              'users/find-friend?expand=isFollowing&searchText=${Uri.encodeQueryComponent(_text)}&searchFrom=1&isExactMatch=&is_chat_user_online=&page=$page',
              'user'),
        ),
      ),
    ]);
  }
}
