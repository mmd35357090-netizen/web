import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../api.dart';
import '../widgets.dart';

class StoryUploadScreen extends StatefulWidget {
  const StoryUploadScreen({super.key});

  @override
  State<StoryUploadScreen> createState() => _StoryUploadScreenState();
}

class _StoryUploadScreenState extends State<StoryUploadScreen> {
  bool _video = false;
  Uint8List? _bytes; // photo, or the cover of a video
  String _name = '';
  String _mime = 'image/jpeg';
  Uint8List? _vBytes;
  String _vName = '';
  String _vMime = 'video/mp4';
  final _caption = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  String _imgMime(String n) {
    final ext = n.split('.').last.toLowerCase();
    return ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
  }

  Future<void> _pickImage() async {
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
    setState(() {
      _bytes = Uint8List.fromList(f.bytes!);
      _name = f.name;
      _mime = _imgMime(f.name);
    });
  }

  Future<void> _pickVideo() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mov', 'webm'],
      withData: true,
    );
    final f = res?.files.first;
    if (f == null || f.bytes == null || !mounted) return;
    if (f.bytes!.length > 50 * 1024 * 1024) {
      toast(context, 'Video is too large (max 50 MB)');
      return;
    }
    final ext = f.name.split('.').last.toLowerCase();
    setState(() {
      _vBytes = Uint8List.fromList(f.bytes!);
      _vName = f.name;
      _vMime = ext == 'mov' ? 'video/quicktime' : (ext == 'webm' ? 'video/webm' : 'video/mp4');
    });
  }

  /// returns {file, fileUrl} of the first uploaded file, or null
  Future<Map?> _upload(String name, Uint8List bytes, String mime) async {
    final up = await Api.upload(name, bytes, mime, type: '3');
    if (up.ok && up.data is Map && up.data['files'] is List && (up.data['files'] as List).isNotEmpty) {
      final first = (up.data['files'] as List).first;
      if (first is Map && first['isProhabited'] != true) return first;
    }
    if (mounted) toast(context, up.message.isEmpty ? 'Could not upload the file' : up.message);
    return null;
  }

  Future<int> _duration(String url) async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize().timeout(const Duration(seconds: 8));
      final s = c.value.duration.inSeconds;
      await c.dispose();
      return s <= 0 ? 15 : s;
    } catch (_) {
      return 15;
    }
  }

  Future<void> _post() async {
    if (_bytes == null || (_video && _vBytes == null)) return;
    setState(() => _busy = true);
    final img = await _upload(_name, _bytes!, _mime);
    if (img == null) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    Map<String, String> item;
    if (_video) {
      final vid = await _upload(_vName, _vBytes!, _vMime);
      if (vid == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final secs = await _duration('${vid['fileUrl']}');
      item = {
        'image': '${img['file']}',
        'video': '${vid['file']}',
        'video_time': '$secs',
        'type': '3',
        'description': _caption.text.trim(),
        'background_color': '',
      };
    } else {
      item = {
        'image': '${img['file']}',
        'video': '',
        'video_time': '0',
        'type': '2',
        'description': _caption.text.trim(),
        'background_color': '',
      };
    }
    final r = await Api.post('stories', {'stories': [item]});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.ok) {
      toast(context, 'Story posted');
      Navigator.of(context).pop(true);
    } else {
      toast(context, r.message.isEmpty ? 'Could not post the story' : r.message);
    }
  }

  Widget _box(String label, IconData icon, Uint8List? preview, VoidCallback onTap, {double h = 320}) {
    return GestureDetector(
      onTap: _busy ? null : onTap,
      child: Container(
        height: h,
        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(16)),
        child: preview == null
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 48),
                  const SizedBox(height: 8),
                  Text(label),
                ]),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(preview, fit: BoxFit.cover, width: double.infinity),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = _bytes != null && (!_video || _vBytes != null);
    return Scaffold(
      appBar: AppBar(title: const Text('New story')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Photo'), icon: Icon(Icons.image_outlined)),
                  ButtonSegment(value: true, label: Text('Video'), icon: Icon(Icons.videocam_outlined)),
                ],
                selected: {_video},
                onSelectionChanged: _busy ? null : (s) => setState(() => _video = s.first),
              ),
              const SizedBox(height: 14),
              if (_video) ...[
                GestureDetector(
                  onTap: _busy ? null : _pickVideo,
                  child: Container(
                    height: 90,
                    decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(16)),
                    child: Center(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_vBytes == null ? Icons.video_file_outlined : Icons.check_circle, size: 32),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(_vBytes == null ? 'Choose a video (max 50 MB)' : _vName,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _box('Choose a cover photo', Icons.add_photo_alternate_outlined, _bytes, _pickImage, h: 220),
              ] else
                _box('Choose a photo', Icons.add_photo_alternate_outlined, _bytes, _pickImage),
              const SizedBox(height: 14),
              TextField(
                controller: _caption,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Caption (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: (!ready || _busy) ? null : _post,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Share story'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
