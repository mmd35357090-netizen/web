import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../widgets.dart';
import 'paged_list.dart';

String _d(dynamic v) {
  final n = int.tryParse('$v');
  if (n == null || n == 0) return '';
  return DateFormat('d MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(n * 1000));
}

bool _hasImg(String s) => s.isNotEmpty && s != 'null';

// ------------------------------------------------------------ offers (coupons)
class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offers')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: TextField(
            onSubmitted: (v) => setState(() => _q = v.trim()),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search offers (press Enter)',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
        Expanded(
          child: PagedList(
            key: ValueKey(_q),
            path: 'coupons?expand=business&name=${Uri.encodeQueryComponent(_q)}',
            listKey: 'coupon',
            empty: 'No offers right now',
            builder: (c, o) {
              final img = str(o['imageUrl']);
              final biz = o['business'] is Map ? str(o['business']['name']) : '';
              return Card(
                clipBehavior: Clip.antiAlias,
                elevation: 0,
                child: InkWell(
                  onTap: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => OfferDetailScreen(offer: o))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (_hasImg(img)) SizedBox(height: 150, width: double.infinity, child: netImage(img, width: double.infinity, height: 150)),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(str(o['name']), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        if (biz.isNotEmpty) Text(biz, style: const TextStyle(color: Colors.black54)),
                        Text('Valid until ${_d(o['expiry_date'])}', style: const TextStyle(color: Colors.black45, fontSize: 12)),
                      ]),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class OfferDetailScreen extends StatefulWidget {
  final Map offer;
  const OfferDetailScreen({super.key, required this.offer});

  @override
  State<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends State<OfferDetailScreen> {
  late bool _fav = '${widget.offer['is_favorite']}' == '1';

  Future<void> _toggle() async {
    final was = _fav;
    setState(() => _fav = !was);
    final r = await Api.post(was ? 'coupons/remove-favorite' : 'coupons/add-favorite',
        {'reference_id': '${widget.offer['id']}', 'type': '1'});
    if (!r.ok && mounted) setState(() => _fav = was);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.offer;
    final img = str(o['imageUrl']);
    final code = str(o['code']);
    return Scaffold(
      appBar: AppBar(title: Text(str(o['name'])), actions: [
        IconButton(
          tooltip: 'Favorite',
          icon: Icon(_fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: _fav ? Colors.red : null),
          onPressed: _toggle,
        ),
      ]),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(children: [
            if (_hasImg(img)) SizedBox(height: 220, width: double.infinity, child: netImage(img, width: double.infinity, height: 220)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(str(o['name']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('${_d(o['start_date'])} - ${_d(o['expiry_date'])}'),
                if (code.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Text('Code: '),
                      Expanded(child: SelectableText(code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
                SelectableText(str(o['description'])),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ fundraising
class FundraisingScreen extends StatefulWidget {
  const FundraisingScreen({super.key});

  @override
  State<FundraisingScreen> createState() => _FundraisingScreenState();
}

class _FundraisingScreenState extends State<FundraisingScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fundraising')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: TextField(
            onSubmitted: (v) => setState(() => _q = v.trim()),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search campaigns (press Enter)',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
        Expanded(
          child: PagedList(
            key: ValueKey(_q),
            path: 'campaigns?expand=donorsDetails,categoryDetails&title=${Uri.encodeQueryComponent(_q)}',
            listKey: 'campaign',
            empty: 'No campaigns right now',
            builder: (c, k) {
              final img = str(k['coverImageUrl']);
              final target = double.tryParse('${k['target_value']}') ?? 0;
              final raised = double.tryParse('${k['raised_value']}') ?? 0;
              final f = target <= 0 ? 0.0 : (raised / target).clamp(0.0, 1.0).toDouble();
              return Card(
                clipBehavior: Clip.antiAlias,
                elevation: 0,
                child: InkWell(
                  onTap: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => CampaignDetailScreen(item: k))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (_hasImg(img)) SizedBox(height: 160, width: double.infinity, child: netImage(img, width: double.infinity, height: 160)),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(str(k['title']), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: f, minHeight: 8, borderRadius: BorderRadius.circular(4)),
                        const SizedBox(height: 4),
                        Text('${raised.toStringAsFixed(0)} raised of ${target.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ]),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class CampaignDetailScreen extends StatelessWidget {
  final Map item;
  const CampaignDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final imgs = <String>[];
    if (item['campaginAllImage'] is List) {
      for (final e in item['campaginAllImage'] as List) {
        if (e is Map && e['campaginImage'] != null) imgs.add(e['campaginImage'].toString());
      }
    }
    if (imgs.isEmpty && _hasImg(str(item['coverImageUrl']))) imgs.add(str(item['coverImageUrl']));
    final target = double.tryParse('${item['target_value']}') ?? 0;
    final raised = double.tryParse('${item['raised_value']}') ?? 0;
    final f = target <= 0 ? 0.0 : (raised / target).clamp(0.0, 1.0).toDouble();
    final by = item['compaigner'] is Map ? str(item['compaigner']['name']) : '';
    return Scaffold(
      appBar: AppBar(title: Text(str(item['title']))),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(children: [
            if (imgs.isNotEmpty)
              SizedBox(
                height: 240,
                child: PageView(children: [for (final u in imgs) netImage(u, width: double.infinity, height: 240)]),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(str(item['title']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                if (by.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('By $by')),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: f, minHeight: 10, borderRadius: BorderRadius.circular(5)),
                const SizedBox(height: 6),
                Text('${raised.toStringAsFixed(0)} raised of ${target.toStringAsFixed(0)}  •  ${str(item['total_donors'])} donors'),
                const SizedBox(height: 4),
                Text('${_d(item['start_date'])} - ${_d(item['end_date'])}', style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 12),
                SelectableText(str(item['description'])),
                const SizedBox(height: 16),
                const Text('To donate, use the mobile app.', style: TextStyle(color: Colors.black45, fontSize: 12)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
