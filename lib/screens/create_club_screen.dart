import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets.dart';

class CreateClubScreen extends StatefulWidget {
  const CreateClubScreen({super.key});

  @override
  State<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends State<CreateClubScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  List<Map> _cats = [];
  int? _cat;
  int _privacy = 1; // 1 public, 2 private, 3 on request
  bool _chat = false;
  Uint8List? _img;
  String _imgName = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Api.get('clubs/category').then((r) {
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
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final res = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'], withData: true);
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;
    setState(() {
      _img = res.files.first.bytes;
      _imgName = res.files.first.name;
    });
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) return toast(context, 'Enter a club name');
    if (_cat == null) return toast(context, 'Choose a category');
    if (_img == null) return toast(context, 'Choose a club photo');
    setState(() => _busy = true);
    final ext = _imgName.split('.').last.toLowerCase();
    final up = await Api.upload(_imgName, _img!, ext == 'png' ? 'image/png' : 'image/jpeg', type: '5');
    String? file;
    if (up.ok && up.data is Map && up.data['files'] is List && (up.data['files'] as List).isNotEmpty) {
      file = (up.data['files'] as List).first['file']?.toString();
    }
    if (!mounted) return;
    if (file == null || file.isEmpty) {
      setState(() => _busy = false);
      return toast(context, up.message.isEmpty ? 'Photo upload failed' : up.message);
    }
    final r = await Api.post('clubs', {
      'category_id': '$_cat',
      'privacy_type': (_privacy == 2 ? 2 : 1).toString(),
      'is_request_based': (_privacy == 3 ? 1 : 0).toString(),
      'is_chat_room': _chat ? '1' : '0',
      'name': _name.text.trim(),
      'image': file,
      'description': _desc.text.trim(),
    });
    if (!mounted) return;
    if (r.ok) {
      toast(context, 'Club created');
      Navigator.pop(context, true);
    } else {
      setState(() => _busy = false);
      toast(context, r.message.isEmpty ? 'Could not create club' : r.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create club')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Center(
              child: InkWell(
                onTap: _pick,
                child: CircleAvatar(
                  radius: 48,
                  backgroundImage: _img == null ? null : MemoryImage(_img!),
                  child: _img == null ? const Icon(Icons.add_a_photo_outlined) : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Club name')),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _cat,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in _cats)
                  DropdownMenuItem(value: int.tryParse('${c['id']}'), child: Text('${c['name']}')),
              ],
              onChanged: (v) => setState(() => _cat = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: _desc, maxLines: 4, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 12),
            RadioGroup<int>(
              groupValue: _privacy,
              onChanged: (v) => setState(() => _privacy = v ?? 1),
              child: const Column(children: [
                RadioListTile<int>(value: 1, title: Text('Public'), subtitle: Text('Anyone can join')),
                RadioListTile<int>(value: 2, title: Text('Private'), subtitle: Text('Members only')),
                RadioListTile<int>(value: 3, title: Text('On request'), subtitle: Text('Join needs approval')),
              ]),
            ),
            SwitchListTile(
              title: const Text('Enable group chat'),
              value: _chat,
              onChanged: (v) => setState(() => _chat = v),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _busy ? null : _create, child: Text(_busy ? 'Please wait...' : 'Create club')),
          ]),
        ),
      ),
    );
  }
}
