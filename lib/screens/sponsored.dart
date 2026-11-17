import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets.dart';
import 'tv_screen.dart';

/// Ads uploaded by the admin ("promotional-ads"). The same list is used for the sponsored cards in the feed
/// and for Watch & Earn.
class SponsoredAd {
  final int id;
  final String name;
  final String image;
  final String video;
  SponsoredAd(this.id, this.name, this.image, this.video);

  bool get isVideo => video.isNotEmpty && video != 'null';
}

class SponsoredAds {
  static List<SponsoredAd>? _cache;
  static DateTime? _at;

  static Future<List<SponsoredAd>> load({bool force = false}) async {
    final fresh = _at != null && DateTime.now().difference(_at!) < const Duration(minutes: 10);
    if (!force && _cache != null && fresh) return _cache!;
    final r = await Api.get('promotional-ads?page=1');
    final out = <SponsoredAd>[];
    final d = r.data is Map ? r.data['ad'] : null;
    final items = d is Map ? d['items'] : null;
    if (r.ok && items is List) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      for (final e in items.whereType<Map>()) {
        final s = int.tryParse('${e['start_date']}') ?? 0;
        final en = int.tryParse('${e['end_date']}') ?? 0;
        if ((s != 0 && now < s) || (en != 0 && now > en)) continue; // outside its dates
        out.add(SponsoredAd(int.tryParse('${e['id']}') ?? 0, '${e['name'] ?? ''}', '${e['imageUrl'] ?? ''}',
            '${e['video'] ?? ''}'));
      }
    }
    _cache = out;
    _at = DateTime.now();
    return out;
  }
}

class SponsoredCard extends StatelessWidget {
  final SponsoredAd ad;
  const SponsoredCard(this.ad, {super.key});

  @override
  Widget build(BuildContext context) {
    final hasImg = ad.image.isNotEmpty && ad.image != 'null';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: ad.isVideo
            ? () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => VideoScreen(title: ad.name, url: ad.video)))
            : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(6)),
                child: const Text('Sponsored', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(ad.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
          ),
          if (hasImg)
            Stack(alignment: Alignment.center, children: [
              SizedBox(height: 220, width: double.infinity, child: netImage(ad.image, width: double.infinity, height: 220)),
              if (ad.isVideo) const Icon(Icons.play_circle_fill_rounded, size: 56, color: Colors.white70),
            ]),
        ]),
      ),
    );
  }
}
