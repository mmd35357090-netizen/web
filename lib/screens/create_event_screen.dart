import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../widgets.dart';

/// Free events only. Paid events (tickets) are created in the mobile app.
class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _name = TextEditingController();
  final _place = TextEditingController();
  final _address = TextEditingController();
  final _desc = TextEditingController();
  final _disclaimer = TextEditingController();
  List<Map> _cats = [];
  int? _cat;
  DateTime? _start;
  DateTime? _end;
  Uint8List? _img;
  String _imgName = '';
  bool _busy = false;

  static final _fmt = DateFormat('yyyy-MM-dd hh:mm a');

  @override
  void initState() {
    super.initState();
    Api.get('categories/event').then((r) {
      if (!mounted) return;
      final l = r.data is Map ? r.data['category'] : null;
      if (l is List) {
        setState(() {
          _cats = l.whereType<Map>().toList();
          if (_cats.isNotEmpty) _cat = int.tryParse('${_cats.first['id']}');
        });
      }
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _place, _address, _desc, _disclaimer]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
    );
    if (d == null || !mounted) return null;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now),
    );
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _pickImage() async {
    final res = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'], withData: true);
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;
    setState(() {
      _img = res.files.first.bytes;
      _imgName = res.files.first.name;
    });
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) return toast(context, 'Enter the event name');
    if (_cat == null) return toast(context, 'Choose a category');
    if (_start == null || _end == null) return toast(context, 'Choose the start and end time');
    if (!_end!.isAfter(_start!)) return toast(context, 'The end time must be after the start time');
    setState(() => _busy = true);
    String file = '';
    if (_img != null) {
      final ext = _imgName.split('.').last.toLowerCase();
      final up = await Api.upload(_imgName, _img!, ext == 'png' ? 'image/png' : 'image/jpeg', type: '13');
      if (up.ok && up.data is Map && up.data['files'] is List && (up.data['files'] as List).isNotEmpty) {
        file = '${(up.data['files'] as List).first['file'] ?? ''}';
      }
      if (file.isEmpty) {
        if (mounted) {
          setState(() => _busy = false);
          toast(context, up.message.isEmpty ? 'Photo upload failed' : up.message);
        }
        return;
      }
    }
    final r = await Api.post('events/create-event', {
      'name': _name.text.trim(),
      'category_id': '$_cat',
      'sub_category_id': '',
      'start_date': _fmt.format(_start!),
      'end_date': _fmt.format(_end!),
      'is_paid': '0',
      'place_name': _place.text.trim(),
      'address': _address.text.trim(),
      'latitude': '',
      'longitude': '',
      'imageFile': file,
      'gallaryFile': '',
      'description': _desc.text.trim(),
      'disclaimer': _disclaimer.text.trim(),
    });
    if (!mounted) return;
    if (r.ok) {
      toast(context, 'Event created');
      Navigator.pop(context, true);
    } else {
      setState(() => _busy = false);
      toast(context, r.message.isEmpty ? 'Could not create the event' : r.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget dateTile(String label, DateTime? v, ValueChanged<DateTime> set) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined),
          title: Text(v == null ? label : _fmt.format(v)),
          trailing: const Icon(Icons.edit_calendar_outlined),
          onTap: () async {
            final d = await _pickDateTime(v);
            if (d != null) setState(() => set(d));
          },
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Create event')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 160,
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(14)),
                child: _img == null
                    ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 36),
                        Text('Cover photo (optional)'),
                      ]))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(_img!, fit: BoxFit.cover, width: double.infinity)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Event name')),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _cat,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [for (final c in _cats) DropdownMenuItem(value: int.tryParse('${c['id']}'), child: Text('${c['name']}'))],
              onChanged: (v) => setState(() => _cat = v),
            ),
            const SizedBox(height: 8),
            dateTile('Starts', _start, (d) {
              _start = d;
              if (_end == null || !_end!.isAfter(d)) _end = d.add(const Duration(hours: 2));
            }),
            dateTile('Ends', _end, (d) => _end = d),
            TextField(controller: _place, decoration: const InputDecoration(labelText: 'Place name')),
            const SizedBox(height: 12),
            TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address')),
            const SizedBox(height: 12),
            TextField(controller: _desc, maxLines: 4, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 12),
            TextField(controller: _disclaimer, maxLines: 2, decoration: const InputDecoration(labelText: 'Disclaimer (optional)')),
            const SizedBox(height: 8),
            const Text('This creates a free event. For paid tickets, use the mobile app.',
                style: TextStyle(color: Colors.black45, fontSize: 12)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _busy ? null : _create, child: Text(_busy ? 'Please wait...' : 'Create event')),
          ]),
        ),
      ),
    );
  }
}
