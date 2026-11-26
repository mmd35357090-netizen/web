import 'dart:async';
import 'package:flutter/material.dart';
import 'buy_ticket_screen.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../widgets.dart';
import 'create_event_screen.dart';

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
  int get endTs => endDate > 0 ? endDate : startDate;
  bool get ended => endTs > 0 && DateTime.now().millisecondsSinceEpoch ~/ 1000 > endTs;

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
          e.tickets.add({'id': '${x['id']}', 'name': '${x['ticket_type']}', 'price': '${x['price']}', 'left': '${x['available_ticket'] ?? ''}'});
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
      appBar: AppBar(title: const Text('Events'), actions: [
        IconButton(
          tooltip: 'My tickets',
          icon: const Icon(Icons.confirmation_number_outlined),
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const MyTicketsScreen())),
        ),
        IconButton(
          tooltip: 'Create event',
          icon: const Icon(Icons.add_circle_outline_rounded),
          onPressed: () async {
            final ok = await Navigator.of(context)
                .push<bool>(MaterialPageRoute(builder: (_) => const CreateEventScreen()));
            if (ok == true && mounted) setState(() {});
          },
        ),
      ]),
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
                                      const SizedBox(height: 6),
                                      Wrap(spacing: 6, children: [
                                        Chip(
                                            visualDensity: VisualDensity.compact,
                                            label: Text(e.free ? 'Free' : 'Paid', style: const TextStyle(fontSize: 12))),
                                        if (e.ended)
                                          const Chip(
                                              visualDensity: VisualDensity.compact,
                                              label: Text('Ended', style: TextStyle(fontSize: 12))),
                                      ]),
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
                if (e.ended)
                  const Padding(padding: EdgeInsets.only(bottom: 8), child: Chip(label: Text('This event has ended'))),
                if (e.free)
                  const Chip(label: Text('Free event'))
                else
                  for (final t in e.tickets)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.confirmation_number_outlined),
                      title: Text(t['name'] ?? ''),
                      subtitle: Text((int.tryParse(t['left'] ?? '') ?? 1) <= 0
                          ? 'Sold out'
                          : ((t['left'] ?? '').isEmpty ? '' : '${t['left']} left')),
                      trailing: Text(t['price'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                const SizedBox(height: 10),
                if (!e.ended && e.tickets.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => BuyTicketScreen(event: e))),
                    icon: const Icon(Icons.confirmation_number_rounded),
                    label: const Text('Buy ticket'),
                  ),
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


/// Tickets I booked (read only; booking itself is in the app).
class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  bool _loading = true;
  bool _upcoming = true;
  List<Map> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await Api.get('events/my-booked-event?current_status=${_upcoming ? 1 : 2}&expand=payment,event,ticketDetail');
    if (!mounted) return;
    final d = r.data is Map ? r.data['eventBooking'] : null;
    final l = d is Map ? d['items'] : null;
    setState(() {
      _loading = false;
      _items = l is List ? l.whereType<Map>().toList() : [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My tickets')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Upcoming')),
              ButtonSegment(value: false, label: Text('Past')),
            ],
            selected: {_upcoming},
            onSelectionChanged: (s) {
              _upcoming = s.first;
              _load();
            },
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? const Center(child: Text('No tickets'))
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          itemCount: _items.length,
                          itemBuilder: (c, i) {
                            final b = _items[i];
                            final ev = EventItem.fromJson(b['event']);
                            final tt = b['ticketDetail'] is Map ? '${(b['ticketDetail'] as Map)['ticket_type']}' : '';
                            final cancelled = '${b['status']}' == '2' || '${b['status']}' == '3';
                            return Card(
                              elevation: 0,
                              child: ListTile(
                                leading: ev.image != null && ev.image!.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: netImage(ev.image!, width: 52, height: 52))
                                    : const Icon(Icons.confirmation_number_outlined),
                                title: Text(ev.name),
                                subtitle: Text('${ev.when}\n${b['ticket_qty']} x $tt${cancelled ? ' · Cancelled' : ''}'),
                                isThreeLine: true,
                                onTap: ev.id == 0
                                    ? null
                                    : () => Navigator.of(context)
                                        .push(MaterialPageRoute(builder: (_) => EventDetailScreen(event: ev))),
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
