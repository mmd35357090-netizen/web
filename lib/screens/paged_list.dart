import 'package:flutter/material.dart';
import '../api.dart';

typedef ItemBuilder = Widget Function(BuildContext context, Map item);

/// Endless list for any "{listKey: {items: [...], _meta: {...}}}" response.
class PagedList extends StatefulWidget {
  final String path; // must already contain a '?'
  final String listKey;
  final ItemBuilder builder;
  final Map<String, dynamic>? postBody; // when set, the request is a POST
  final String empty;
  const PagedList({
    super.key,
    required this.path,
    required this.listKey,
    required this.builder,
    this.postBody,
    this.empty = 'Nothing here yet',
  });

  @override
  State<PagedList> createState() => _PagedListState();
}

class _PagedListState extends State<PagedList> {
  final List<Map> _items = [];
  final _scroll = ScrollController();
  int _page = 1;
  int _pages = 1;
  bool _loading = false;
  bool _first = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || _page > _pages) return;
    _loading = true;
    final url = '${widget.path}&page=$_page';
    final r = widget.postBody == null ? await Api.get(url) : await Api.post(url, widget.postBody!);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _first = true;
      final d = r.data is Map ? r.data[widget.listKey] : null;
      if (r.ok && d is Map) {
        final items = d['items'];
        if (items is List) _items.addAll(items.whereType<Map>());
        final meta = d['_meta'];
        if (meta is Map) _pages = int.tryParse('${meta['pageCount']}') ?? _page;
        _page += 1;
      } else if (!r.ok) {
        _error = r.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_first) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return Center(child: Text(_error.isEmpty ? widget.empty : _error));
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(10),
          itemCount: _items.length,
          itemBuilder: (c, i) => widget.builder(c, _items[i]),
        ),
      ),
    );
  }
}

String str(dynamic v) => v == null ? '' : v.toString();
