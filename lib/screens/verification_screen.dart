import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../widgets.dart';
import 'paged_list.dart';

/// Blue tick: apply with an ID document, see the status, cancel a pending request.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  static const _maxFailed = 3;
  static const _types = ['NID', 'Passport', 'Driving license', 'Birth certificate', 'Other'];

  bool _loading = true;
  bool _busy = false;
  bool _verified = false;
  List<Map> _items = [];

  String _type = _types.first;
  final _number = TextEditingController();
  final _message = TextEditingController();
  final List<({String name, Uint8List bytes})> _images = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _number.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final me = await Api.get('users/profile');
    final r = await Api.get('user-verifications');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (me.data is Map && me.data['user'] is Map) {
        _verified = '${(me.data['user'] as Map)['is_verified']}' == '1';
      }
      final v = r.data is Map ? r.data['verification'] : null;
      final l = v is Map ? v['items'] : null;
      _items = l is List ? l.whereType<Map>().toList() : [];
    });
  }

  int _st(Map m) => int.tryParse('${m['status']}') ?? 0;
  bool get _approved => _verified || _items.any((m) => _st(m) == 10);
  Map? get _pending {
    for (final m in _items) {
      if (_st(m) == 1) return m;
    }
    return null;
  }

  List<Map> get _rejected => _items.where((m) => _st(m) == 3).toList();
  bool get _blocked => _rejected.length >= _maxFailed && !_approved;

  String _date(dynamic ts) {
    final s = int.tryParse('$ts') ?? 0;
    if (s == 0) return '';
    return DateFormat('d MMM yyyy, h:mm a').format(DateTime.fromMillisecondsSinceEpoch(s * 1000));
  }

  Future<void> _pick() async {
    if (_images.length >= 4) return toast(context, 'Up to 4 photos');
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final f = res?.files.first;
    if (f == null || f.bytes == null || !mounted) return;
    if (f.bytes!.length > 8 * 1024 * 1024) return toast(context, 'Photo is too large (max 8 MB)');
    setState(() => _images.add((name: f.name, bytes: Uint8List.fromList(f.bytes!))));
  }

  Future<void> _submit() async {
    final number = _number.text.trim();
    final isNid = _type == 'NID';
    final isOther = _type == 'Other';
    if (!isOther && number.isEmpty) return toast(context, 'Please enter your document number');
    if (isNid && !RegExp(r'^(\d{10}|\d{13}|\d{17})$').hasMatch(number)) {
      return toast(context, 'NID number must be 10, 13 or 17 digits');
    }
    if (number.isNotEmpty && number.length < 4) return toast(context, 'Document number is too short');
    if (_images.isEmpty) return toast(context, 'Please upload a photo of your document');

    setState(() => _busy = true);
    final docs = <Map<String, String>>[];
    for (final img in _images) {
      final ext = img.name.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
      final up = await Api.upload(img.name, img.bytes, mime, type: '12');
      String? file;
      if (up.ok && up.data is Map && up.data['files'] is List && (up.data['files'] as List).isNotEmpty) {
        file = (up.data['files'] as List).first['file']?.toString();
      }
      if (file == null || file.isEmpty) {
        if (!mounted) return;
        setState(() => _busy = false);
        return toast(context, up.message.isEmpty ? 'Upload failed' : up.message);
      }
      docs.add({'filename': file, 'media_type': '1', 'title': ''});
    }
    final r = await Api.post('user-verifications', {
      'user_message': _message.text.trim(),
      'document': docs,
      'document_type': _type,
      'document_number': number,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.ok) {
      toast(context, 'Request sent. We will review it soon.');
      _images.clear();
      _number.clear();
      _message.clear();
      setState(() => _loading = true);
      _load();
    } else {
      toast(context, r.message.isEmpty ? 'Could not send the request' : r.message);
    }
  }

  Future<void> _cancel(Map m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel request?'),
        content: const Text('You can send a new request afterwards.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep it')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cancel request')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final r = await Api.post('user-verifications/cancel', {'id': '${m['id']}', 'user_message': ''});
    if (!mounted) return;
    toast(context, r.ok ? 'Request cancelled' : (r.message.isEmpty ? 'Failed' : r.message));
    _load();
  }

  Widget _status(IconData icon, Color color, String title, String text, {Widget? action}) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(children: [
          CircleAvatar(radius: 34, backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color, size: 36)),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(text, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 12), action],
        ]),
      ),
    );
  }

  Widget _form() {
    final rej = _rejected;
    final reason = rej.isEmpty ? '' : str(rej.first['admin_message']).trim();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (rej.isNotEmpty)
        Card(
          color: Colors.red.withValues(alpha: 0.08),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Your last request was not approved.',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
              if (reason.isNotEmpty && reason != 'null') Text(reason),
              Text('Attempts left: ${(_maxFailed - rej.length).clamp(0, _maxFailed)} of $_maxFailed'),
            ]),
          ),
        ),
      const Text('Document type', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        value: _type,
        items: [for (final t in _types) DropdownMenuItem(value: t, child: Text(t))],
        onChanged: (v) => setState(() => _type = v ?? _type),
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _number,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: _type == 'Other' ? 'Document number (optional)' : 'Document number',
          helperText: _type == 'NID' ? 'NID: 10, 13 or 17 digits' : null,
        ),
      ),
      const SizedBox(height: 14),
      const Text('Photos of the document', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 0; i < _images.length; i++)
          Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(_images[i].bytes, width: 96, height: 96, fit: BoxFit.cover),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: InkWell(
                onTap: () => setState(() => _images.removeAt(i)),
                child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
              ),
            ),
          ]),
        InkWell(
          onTap: _busy ? null : _pick,
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.add_a_photo_outlined),
          ),
        ),
      ]),
      const SizedBox(height: 14),
      TextField(
        controller: _message,
        maxLines: 3,
        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Message (optional)'),
      ),
      const SizedBox(height: 16),
      FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Sending...' : 'Send request')),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = _pending;
    Widget body;
    if (_loading) {
      body = const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
    } else if (_approved) {
      final ap = _items.where((m) => _st(m) == 10).toList();
      body = _status(Icons.verified_rounded, Colors.green, 'Verified', 'Your account has the blue tick.',
          action: ap.isEmpty ? null : Text('Verified on ${_date(ap.first['updated_at'] ?? ap.first['created_at'])}'));
    } else if (p != null) {
      body = _status(Icons.hourglass_top_rounded, Theme.of(context).colorScheme.primary, 'Under review',
          'We are reviewing your documents. You will be notified when it is done.',
          action: Column(children: [
            Text('Sent on ${_date(p['created_at'])}'),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => _cancel(p), child: const Text('Cancel request')),
          ]));
    } else if (_blocked) {
      body = _status(Icons.block_rounded, Colors.red, 'Verification blocked',
          '$_maxFailed of your requests were rejected, so you can not apply again. Please contact support if this is a mistake.');
    } else {
      body = _form();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Get verified')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(padding: const EdgeInsets.all(16), children: [body]),
        ),
      ),
    );
  }
}
