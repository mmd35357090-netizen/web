import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../widgets.dart';

class EventItem {
  int id = 0;
  String name = '';
  String? image;
  int startDate = 0;
  int endDate = 0;
  String place = '';
  String address = '';
  String description = '';
  String disclaimer = '';
  bool free = true;
  List<Map<String, String>> tickets = [];

  EventItem();

  static int _i(dynamic v) => int.tryParse('$v') ?? 0;

  factory EventItem.fromJson(dynamic j) {
    final e = EventItem();
    if (j is! Map) return e;
    e.id = _i(j['id']);
    e.name = (j['name'] ?? '').toString();
    e.image = j['imageUrl']?.toString();
    e.startDate = _i(j['start_date']);
    e.endDate = _i(j['end_date']);
    e.place = (j['place_name'] ?? '').toString();
    e.address = (j['address'] ?? '').toString();
    e.description = (j['description'] ?? '').toString();
    e.disclaimer = (j['disclaimer'] ?? '').toString();
    e.free = _i(j['is_paid']) == 0;
    final t = j['eventTicket'];
    if (t is List) {
      for (final x in t) {
        if (x is Map) {
          e.tickets.add({'name': '${x['ticket_type']}', 'price': '${x['price']}'});
        }
      }
    }
    return e;
  }

  String get when {
    if (startDate == 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(startDate * 1000);
    return DateFormat('EEE, d MMM yyyy • h:mm a').format(d);
  }
}

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final List<EventItem> _items = [];
  final _scroll = ScrollController();
  final _search = TextEditingController();
  Timer? _debounce;
  String _text = '';
  int _page = 1;
  int _pages = 1;
  bool _loading = false;
  bool _first = false;

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
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _reset() {
    _items.clear();
    _page = 1;
    _pages = 1;
    _first = false;
    _load();
  }

  Future<void> _load() async {
    if (_loading || _page > _pages) return;
    _loading = true;
    final r = await Api.get(
        'events?expand=createdByUser,eventTicket&name=${Uri.encodeQueryComponent(_text)}&page=$_page');
    if (!mounted) return;
    setState(() {
      _loading = false;
      _first = true;
      final d = r.data is Map ? r.data['event'] : null;
      if (r.ok && d is Map) {
        final items = d['items'];
        if (items is List) _items.addAll(items.map((e) => EventItem.fromJson(e)).where((x) => x.id > 0));
        final meta = d['_meta'];
        if (meta is Map) _pages = int.tryParse('${meta['pageCount']}') ?? _page;
        _page += 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: TextField(
            controller: _search,
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 450), () {
                _text = v.trim();
                if (mounted) setState(_reset);
              });
            },
            decoration: InputDecoration(
              hintText: 'Search events',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
        Expanded(
          child: !_first
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? const Center(child: Text('No events found'))
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.all(10),
                          itemCount: _items.length,
                          itemBuilder: (c, i) {
                            final e = _items[i];
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              elevation: 0,
                              child: InkWell(
                                onTap: () => Navigator.of(context)
                                    .push(MaterialPageRoute(builder: (_) => EventDetailScreen(event: e))),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  if (e.image != null && e.image!.isNotEmpty)
                                    SizedBox(
                                        height: 160,
                                        width: double.infinity,
                                        child: netImage(e.image!, width: double.infinity, height: 160)),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(e.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Text(e.when, style: const TextStyle(color: Colors.black54)),
                                      if (e.place.isNotEmpty)
                                        Text(e.place, style: const TextStyle(color: Colors.black54)),
                                    ]),
                                  ),
                                ]),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }
}

class EventDetailScreen extends StatelessWidget {
  final EventItem event;
  const EventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final e = event;
    return Scaffold(
      appBar: AppBar(title: Text(e.name)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(children: [
            if (e.image != null && e.image!.isNotEmpty)
              SizedBox(height: 220, width: double.infinity, child: netImage(e.image!, width: double.infinity, height: 220)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Row(children: [const Icon(Icons.schedule_rounded, size: 18), const SizedBox(width: 8), Expanded(child: Text(e.when))]),
                if (e.place.isNotEmpty || e.address.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.place_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text([e.place, e.address].where((x) => x.isNotEmpty).join(', '))),
                  ]),
                ],
                const SizedBox(height: 14),
                if (e.description.isNotEmpty) SelectableText(e.description),
                const SizedBox(height: 14),
                if (e.free)
                  const Chip(label: Text('Free event'))
                else
                  for (final t in e.tickets)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.confirmation_number_outlined),
                      title: Text(t['name'] ?? ''),
                      trailing: Text(t['price'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                const SizedBox(height: 10),
                const Text('Tickets can be booked in the mobile app.',
                    style: TextStyle(color: Colors.black45, fontSize: 12)),
                if (e.disclaimer.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(e.disclaimer, style: const TextStyle(color: Colors.black45, fontSize: 12)),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
