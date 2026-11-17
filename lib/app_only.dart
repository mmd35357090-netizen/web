import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'config.dart';

/// One place that tells people "this needs the mobile app" and sends them to the store.
class AppOnly {
  static bool get hasStoreLink => AppConfig.playStoreUrl.isNotEmpty || AppConfig.appStoreUrl.isNotEmpty;

  static void openStore() {
    final ua = web.window.navigator.userAgent.toLowerCase();
    final ios = ua.contains('iphone') || ua.contains('ipad');
    final url = (ios && AppConfig.appStoreUrl.isNotEmpty)
        ? AppConfig.appStoreUrl
        : (AppConfig.playStoreUrl.isNotEmpty ? AppConfig.playStoreUrl : AppConfig.appStoreUrl);
    if (url.isNotEmpty) web.window.open(url, '_blank');
  }

  /// Dialog shown when somebody taps a feature that only exists in the app.
  static Future<void> show(BuildContext context, String feature, {String? why}) {
    return showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(Icons.smartphone_rounded, size: 36, color: Theme.of(c).colorScheme.primary),
        title: Text(feature, textAlign: TextAlign.center),
        content: Text(
          why ?? 'This feature works only in the ${AppConfig.appName} mobile app.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Not now')),
          if (hasStoreLink)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(c);
                openStore();
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text('Get the app'),
            ),
        ],
      ),
    );
  }
}

/// Small inline note with a button, used under details pages ("To apply, use the app").
class AppOnlyNote extends StatelessWidget {
  final String text;
  const AppOnlyNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(Icons.smartphone_rounded, color: cs.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        if (AppOnly.hasStoreLink)
          TextButton(onPressed: AppOnly.openStore, child: const Text('Get the app')),
      ]),
    );
  }
}
