import 'package:flutter/material.dart';
import '../app_only.dart';
import 'package:intl/intl.dart';
import '../widgets.dart';
import 'paged_list.dart';

String _date(dynamic v) {
  final n = int.tryParse('$v');
  if (n == null || n == 0) return '';
  return DateFormat('d MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(n * 1000));
}

class CompetitionsScreen extends StatelessWidget {
  const CompetitionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Competitions')),
      body: PagedList(
        path: 'competitions?expand=competitionPosition',
        listKey: 'competition',
        empty: 'No competitions right now',
        builder: (c, j) {
          final img = str(j['imageUrl']);
          return Card(
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            child: InkWell(
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => CompetitionDetailScreen(item: j))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (img.isNotEmpty) SizedBox(height: 150, width: double.infinity, child: netImage(img, width: double.infinity, height: 150)),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(str(j['title']), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${_date(j['start_date'])} - ${_date(j['end_date'])}',
                        style: const TextStyle(color: Colors.black54)),
                  ]),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class CompetitionDetailScreen extends StatelessWidget {
  final Map item;
  const CompetitionDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final img = str(item['imageUrl']);
    final fee = int.tryParse('${item['joining_fee']}') ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(str(item['title']))),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(children: [
            if (img.isNotEmpty) SizedBox(height: 220, width: double.infinity, child: netImage(img, width: double.infinity, height: 220)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(str(item['title']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('${_date(item['start_date'])} - ${_date(item['end_date'])}'),
                const SizedBox(height: 4),
                Text(fee == 0 ? 'Free to join' : 'Joining fee: $fee coins'),
                const SizedBox(height: 12),
                SelectableText(str(item['description'])),
                const SizedBox(height: 16),
                const AppOnlyNote('Joining a competition and submitting your entry works in the mobile app.'),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
