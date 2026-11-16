import 'package:flutter/material.dart';
import '../widgets.dart';
import 'paged_list.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String _q = '';

  String? _img(Map a) {
    final im = a['images'];
    if (im is List && im.isNotEmpty) return im.first.toString();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shop')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: TextField(
            onSubmitted: (v) => setState(() => _q = v.trim()),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search products (press Enter)',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
        Expanded(
          child: PagedList(
            key: ValueKey(_q),
            path: 'ads/ad-search?expand=user.subscriptionPlanUser,facility',
            postBody: {'title': _q},
            listKey: 'ad',
            empty: 'No products found',
            builder: (c, a) {
              final img = _img(a);
              return Card(
                elevation: 0,
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: img == null
                          ? const ColoredBox(color: Colors.black12, child: Icon(Icons.image_outlined))
                          : netImage(img, width: 56, height: 56),
                    ),
                  ),
                  title: Text(str(a['title']), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${str(a['currency'])} ${str(a['price'])}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => AdDetailScreen(ad: a))),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class AdDetailScreen extends StatelessWidget {
  final Map ad;
  const AdDetailScreen({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    final imgs = (ad['images'] is List) ? (ad['images'] as List).map((e) => e.toString()).toList() : <String>[];
    final seller = ad['user'] is Map ? str(ad['user']['name']) : '';
    return Scaffold(
      appBar: AppBar(title: Text(str(ad['title']))),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(children: [
            if (imgs.isNotEmpty)
              SizedBox(
                height: 280,
                child: PageView(children: [
                  for (final u in imgs) netImage(u, width: double.infinity, height: 280, fit: BoxFit.contain),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(str(ad['title']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('${str(ad['currency'])} ${str(ad['price'])}',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
                if (seller.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Seller: $seller')),
                if (str(ad['phone']).isNotEmpty && str(ad['phone']) != 'null')
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text('Phone: ${str(ad['phone'])}')),
                const SizedBox(height: 12),
                SelectableText(str(ad['description'])),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
