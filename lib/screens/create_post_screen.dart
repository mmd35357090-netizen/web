import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets.dart';

class _Picked {
  final String name;
  final List<int> bytes;
  final bool video;
  _Picked(this.name, this.bytes, this.video);
}

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const _maxImage = 15 * 1024 * 1024;
  static const _maxVideo = 100 * 1024 * 1024;
  static const _videoExt = ['mp4', 'mov', 'webm', 'mkv', '3gp', 'avi'];

  final _text = TextEditingController();
  final List<_Picked> _files = [];
  bool _comments = true;
  bool _asReel = false;
  bool _busy = false;
  String _status = '';

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String _mime(String name) {
    final e = name.split('.').last.toLowerCase();
    switch (e) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'mkv':
        return 'video/x-matroska';
      case '3gp':
        return 'video/3gpp';
      case 'avi':
        return 'video/x-msvideo';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _pick() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', ..._videoExt],
      allowMultiple: true,
      withData: true,
    );
    if (res == null || !mounted) return;
    for (final f in res.files) {
      final bytes = f.bytes;
      if (bytes == null) continue;
      final ext = f.name.split('.').last.toLowerCase();
      final isVideo = _videoExt.contains(ext);
      if (bytes.length > (isVideo ? _maxVideo : _maxImage)) {
        toast(context, '${f.name} is too large (max ${isVideo ? '100' : '15'} MB)');
        continue;
      }
      if (_files.length >= 10) break;
      _files.add(_Picked(f.name, bytes, isVideo));
    }
    // a post is either photos or videos; keep it simple
    setState(() {
      if (!_files.any((x) => x.video)) _asReel = false;
    });
  }

  List<String> _tags(String t) {
    final out = <String>{};
    for (final m in RegExp(r'#([\p{L}\p{N}_]+)', unicode: true).allMatches(t)) {
      out.add(m.group(1)!);
    }
    return out.toList();
  }

  Future<void> _publish() async {
    final text = _text.text.trim();
    if (text.isEmpty && _files.isEmpty) {
      toast(context, 'Write something or add a photo/video');
      return;
    }
    setState(() {
      _busy = true;
      _status = '';
    });

    final gallery = <Map<String, String>>[];
    for (int i = 0; i < _files.length; i++) {
      final f = _files[i];
      setState(() => _status = 'Uploading ${i + 1} of ${_files.length}...');
      final r = await Api.upload(f.name, Uint8List.fromList(f.bytes), _mime(f.name));
      String? file;
      if (r.ok && r.data is Map && r.data['files'] is List && (r.data['files'] as List).isNotEmpty) {
        final first = (r.data['files'] as List).first;
        if (first is Map && first['isProhabited'] != true) file = first['file']?.toString();
      }
      if (file == null) {
        if (!mounted) return;
        setState(() => _busy = false);
        toast(context, r.message.isNotEmpty ? r.message : 'Could not upload ${f.name}');
        return;
      }
      gallery.add({
        'filename': file,
        'video_thumb': '',
        'type': '1',
        'media_type': f.video ? '2' : '1',
        'is_default': '1',
        'height': '0',
        'width': '0',
        'audio_time': '0',
      });
    }

    setState(() => _status = 'Publishing...');
    final r = await Api.post('posts', {
      'type': _asReel ? '4' : '1',
      'origin_post_id': null,
      'title': text,
      'hashtag': _tags(text).join(','),
      'mentionUser': '',
      'gallary': gallery,
      'post_content_type': gallery.isEmpty ? '1' : '2',
      'is_add_to_post': 1,
      'display_whose': 1,
      'is_comment_enable': _comments ? 1 : 0,
      'latitude': '',
      'longitude': '',
      'address': '',
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.ok) {
      toast(context, 'Posted');
      Navigator.of(context).pop(true);
    } else {
      toast(context, r.message.isNotEmpty ? r.message : 'Could not publish');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = _files.any((x) => x.video);
    return Scaffold(
      appBar: AppBar(
        title: const Text('New post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _busy ? null : _publish,
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Post'),
            ),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextField(
              controller: _text,
              enabled: !_busy,
              maxLines: 6,
              minLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: "What's on your mind? Use #hashtags",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (int i = 0; i < _files.length; i++)
                Chip(
                  avatar: Icon(_files[i].video ? Icons.videocam_rounded : Icons.image_rounded, size: 18),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(_files[i].name, overflow: TextOverflow.ellipsis),
                  ),
                  onDeleted: _busy
                      ? null
                      : () => setState(() {
                            _files.removeAt(i);
                            if (!_files.any((x) => x.video)) _asReel = false;
                          }),
                ),
              ActionChip(
                avatar: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('Photo / Video'),
                onPressed: _busy ? null : _pick,
              ),
            ]),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow comments'),
              value: _comments,
              onChanged: _busy ? null : (v) => setState(() => _comments = v),
            ),
            if (hasVideo)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Share as a reel'),
                value: _asReel,
                onChanged: _busy ? null : (v) => setState(() => _asReel = v),
              ),
            if (_status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_status, style: const TextStyle(color: Colors.black54)),
              ),
          ]),
        ),
      ),
    );
  }
}
