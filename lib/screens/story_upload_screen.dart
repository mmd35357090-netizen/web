import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets.dart';

class StoryUploadScreen extends StatefulWidget {
  const StoryUploadScreen({super.key});

  @override
  State<StoryUploadScreen> createState() => _StoryUploadScreenState();
}

class _StoryUploadScreenState extends State<StoryUploadScreen> {
  Uint8List? _bytes;
  String _name = '';
  String _mime = 'image/jpeg';
  final _caption = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final f = res?.files.first;
    if (f == null || f.bytes == null || !mounted) return;
    if (f.bytes!.length > 10 * 1024 * 1024) {
      toast(context, 'Photo is too large (max 10 MB)');
      return;
    }
    final ext = f.name.split('.').last.toLowerCase();
    setState(() {
      _bytes = Uint8List.fromList(f.bytes!);
      _name = f.name;
      _mime = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
    });
  }

  Future<void> _post() async {
    if (_bytes == null) return;
    setState(() => _busy = true);
    final up = await Api.upload(_name, _bytes!, _mime, type: '3');
    String? file;
    if (up.ok && up.data is Map && up.data['files'] is List && (up.data['files'] as List).isNotEmpty) {
      final first = (up.data['files'] as List).first;
      if (first is Map && first['isProhabited'] != true) file = first['file']?.toString();
    }
    if (file == null) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, up.message.isEmpty ? 'Could not upload the photo' : up.message);
      }
      return;
    }
    final r = await Api.post('stories', {
      'stories': [
        {
          'image': file,
          'video': '',
          'video_time': '0',
          'type': '2',
          'description': _caption.text.trim(),
          'background_color': '',
        }
      ]
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.ok) {
      toast(context, 'Story posted');
      Navigator.of(context).pop(true);
    } else {
      toast(context, r.message.isEmpty ? 'Could not post the story' : r.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New story')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              GestureDetector(
                onTap: _busy ? null : _pick,
                child: Container(
                  height: 320,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _bytes == null
                      ? const Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 48),
                            SizedBox(height: 8),
                            Text('Choose a photo'),
                          ]),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(_bytes!, fit: BoxFit.cover),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _caption,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Caption (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: (_bytes == null || _busy) ? null : _post,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Share story'),
              ),
              const SizedBox(height: 8),
              const Text('Video stories can be added from the mobile app.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.black45, fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }
}
