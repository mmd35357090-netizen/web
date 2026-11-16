import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../session.dart';
import '../widgets.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _bio = TextEditingController();
  final _country = TextEditingController();
  final _city = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _username, _bio, _country, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final r = await Api.get('users/profile');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok && r.data is Map && r.data['user'] is Map) {
        final j = r.data['user'] as Map;
        _user = AppUser.fromJson(j);
        _name.text = _user!.name;
        _username.text = _user!.username;
        _bio.text = _user!.bio;
        _country.text = (j['country'] ?? '').toString();
        _city.text = (j['city'] ?? '').toString();
      }
    });
  }

  Future<void> _photo() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final f = res?.files.first;
    if (f == null || f.bytes == null || !mounted) return;
    if (f.bytes!.length > 8 * 1024 * 1024) {
      toast(context, 'Photo is too large (max 8 MB)');
      return;
    }
    setState(() => _busy = true);
    final ext = f.name.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
    final r = await Api.uploadProfileImage(f.name, Uint8List.fromList(f.bytes!), mime);
    if (!mounted) return;
    setState(() => _busy = false);
    toast(context, r.ok ? 'Photo updated' : (r.message.isEmpty ? 'Could not update photo' : r.message));
    if (r.ok) {
      Session.clear();
      _load();
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final r = await Api.post('users/profile-update', {
      'name': _name.text.trim(),
      'username': _username.text.trim(),
      'bio': _bio.text.trim(),
      'country': _country.text.trim(),
      'city': _city.text.trim(),
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.ok) {
      Session.clear();
      toast(context, 'Profile updated');
      Navigator.of(context).pop(true);
    } else {
      toast(context, r.message.isEmpty ? 'Could not save' : r.message);
    }
  }

  Widget _field(String label, TextEditingController c, {int lines = 1, int? max}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: c,
          maxLines: lines,
          maxLength: max,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  Center(
                    child: Column(children: [
                      if (_user != null) Avatar(_user!, size: 90),
                      TextButton(onPressed: _busy ? null : _photo, child: const Text('Change photo')),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  _field('Name', _name, max: 60),
                  _field('Username', _username, max: 30),
                  _field('Bio', _bio, lines: 3, max: 250),
                  _field('Country', _country),
                  _field('City', _city),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save'),
                  ),
                ]),
              ),
            ),
    );
  }
}
