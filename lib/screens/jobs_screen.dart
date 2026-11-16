import 'package:flutter/material.dart';
import 'paged_list.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jobs')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: TextField(
            onSubmitted: (v) => setState(() => _q = v.trim()),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search jobs (press Enter)',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
        Expanded(
          child: PagedList(
            key: ValueKey(_q),
            path: 'jobs?title=${Uri.encodeQueryComponent(_q)}',
            listKey: 'jobs',
            empty: 'No jobs found',
            builder: (c, j) {
              final place = [str(j['city_name']), str(j['country_name'])].where((x) => x.isNotEmpty && x != 'null').join(', ');
              final org = j['organization'] is Map ? str(j['organization']['name']) : '';
              return Card(
                elevation: 0,
                child: ListTile(
                  title: Text(str(j['title']), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([org, place].where((x) => x.isNotEmpty).join(' • ')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => JobDetailScreen(job: j))),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class JobDetailScreen extends StatelessWidget {
  final Map job;
  const JobDetailScreen({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final org = job['organization'] is Map ? str(job['organization']['name']) : '';
    final place = [str(job['city_name']), str(job['state_name']), str(job['country_name'])]
        .where((x) => x.isNotEmpty && x != 'null')
        .join(', ');
    Widget row(IconData i, String t) =>
        t.isEmpty ? const SizedBox.shrink() : Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(i, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(t)),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Job')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text(str(job['title']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            row(Icons.business_outlined, org),
            row(Icons.place_outlined, place),
            row(Icons.payments_outlined, 'Salary: ${str(job['salary_min'])} - ${str(job['salary_max'])}'),
            row(Icons.timeline_rounded, 'Experience: ${str(job['experience_min'])} - ${str(job['experience_max'])} years'),
            row(Icons.school_outlined, str(job['education'])),
            row(Icons.build_outlined, str(job['skill'])),
            const SizedBox(height: 8),
            SelectableText(str(job['description'])),
            const SizedBox(height: 16),
            const Text('To apply, use the mobile app.', style: TextStyle(color: Colors.black45, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}
