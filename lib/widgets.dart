import 'package:flutter/material.dart';
import 'models.dart';

/// Image that works on the web even when the image server has no CORS headers
Widget netImage(String url,
    {BoxFit fit = BoxFit.cover, double? width, double? height, Widget? error}) {
  return Image.network(
    url,
    fit: fit,
    width: width,
    height: height,
    webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
    errorBuilder: (c, e, s) =>
        error ??
        Container(
          width: width,
          height: height,
          color: const Color(0xFFE9ECF3),
          child: const Icon(Icons.broken_image_outlined, color: Colors.black26),
        ),
    loadingBuilder: (c, child, progress) {
      if (progress == null) return child;
      return Container(
        width: width,
        height: height,
        color: const Color(0xFFEFF1F7),
      );
    },
  );
}

class Avatar extends StatelessWidget {
  final AppUser user;
  final double size;
  const Avatar(this.user, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final letter = user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?';
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1),
      ),
      child: Text(letter,
          style: TextStyle(
              fontSize: size * 0.42,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary)),
    );
    final pic = user.picture;
    if (pic == null || pic.isEmpty) return fallback;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: netImage(pic, width: size, height: size, error: fallback),
      ),
    );
  }
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      width: 420,
    ));
}
