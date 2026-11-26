import 'package:flutter/material.dart';
import '../api.dart';
import 'paged_list.dart';
import '../widgets.dart';

/// Dating plans: more profiles per day, paid with coins.
class DatingPlansScreen extends StatefulWidget {
  const DatingPlansScreen({super.key});

  @override
  State<DatingPlansScreen> createState() => _DatingPlansScreenState();
}

class _DatingPlansScreenState extends State<DatingPlansScreen> {
  bool _loading = true;
  int _busyId = 0;
  List<Map> _plans = [];

  static const _dur = {1: '1 week', 2: '1 month', 3: '3 months', 4: '6 months', 5: '1 year'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Api.get('datings/subscription-package');
    if (!mounted) return;
    final l = r.data is Map ? r.data['datingPackage'] : null;
    setState(() {
      _loading = false;
      _plans = l is List ? l.whereType<Map>().toList() : [];
    });
  }

  Future<void> _buy(Map p) async {
    final id = int.tryParse('${p['id']}') ?? 0;
    final coin = int.tryParse('${p['coin']}') ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(str(p['name'])),
        content: Text('Pay $coin coins for this plan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Subscribe')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busyId = id);
    final r = await Api.post('datings/subscribe-package', {'dating_subscription_id': '$id'});
    if (!mounted) return;
    setState(() => _busyId = 0);
    toast(context, r.ok ? 'Plan activated' : (r.message.isEmpty ? 'Could not subscribe' : r.message));
    if (r.ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dating plans')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? const Center(child: Text('No plans available'))
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _plans.length,
                      itemBuilder: (c, i) {
                        final p = _plans[i];
                        final id = int.tryParse('${p['id']}') ?? 0;
                        final d = _dur[int.tryParse('${p['duration']}') ?? 0] ?? '';
                        final isDef = '${p['is_default']}' == '1';
                        return Card(
                          elevation: 0,
                          child: ListTile(
                            leading: const Icon(Icons.workspace_premium_rounded, color: Colors.amber),
                            title: Text(str(p['name'])),
                            subtitle: Text('${p['number_of_profiles']} profiles/day${d.isEmpty ? '' : ' · $d'}'),
                            trailing: isDef
                                ? const Chip(label: Text('Free'))
                                : FilledButton(
                                    onPressed: _busyId != 0 ? null : () => _buy(p),
                                    child: _busyId == id
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                        : Text('${p['coin']} coins'),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                );
  }
}
