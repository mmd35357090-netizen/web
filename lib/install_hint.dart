import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

@JS('cfgIosInstallable')
external JSBoolean _iosInstallable();

/// On iPhone / iPad Safari, shows how to add the site to the Home Screen (works like an app).
/// Hidden once dismissed, and never shown when already installed.
class InstallHint extends StatefulWidget {
  const InstallHint({super.key});

  @override
  State<InstallHint> createState() => _InstallHintState();
}

class _InstallHintState extends State<InstallHint> {
  static const _key = 'install_hint_dismissed';
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      if (!_iosInstallable().toDart) return;
      final p = await SharedPreferences.getInstance();
      if (p.getBool(_key) == true) return;
      if (mounted) setState(() => _show = true);
    } catch (_) {}
  }

  Future<void> _dismiss() async {
    setState(() => _show = false);
    try {
      (await SharedPreferences.getInstance()).setBool(_key, true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
        child: Row(children: [
          Icon(Icons.ios_share_rounded, color: cs.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Install: tap Share, then "Add to Home Screen" to use this like an app.',
                style: TextStyle(fontSize: 13)),
          ),
          IconButton(onPressed: _dismiss, icon: const Icon(Icons.close_rounded), tooltip: 'Close'),
        ]),
      ),
    );
  }
}
