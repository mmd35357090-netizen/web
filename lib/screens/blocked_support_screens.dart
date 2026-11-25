import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../widgets.dart';
import 'paged_list.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  int _k = 0;

  Future<void> _unblock(int id) async {
    final r = await Api.post('blocked-users/un-blocked', {'blocked_user_id': '$id'});
    if (!mounted) return;
    if (r.ok) {
      toast(context, 'Unblocked');
      setState(() => _k++);
    } else {
      toast(context, r.message.isEmpty ? 'Could not unblock' : r.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked users')),
      body: PagedList(
        key: ValueKey(_k),
        path: 'blocked-users?expand=blockedUserDetail',
        listKey: 'blockedUser',
        empty: 'You have not blocked anyone',
        builder: (c, b) {
          final d = b['blockedUserDetail'];
          if (d == null) return const SizedBox.shrink();
          final u = AppUser.fromJson(d);
          return Card(
            elevation: 0,
            child: ListTile(
              leading: Avatar(u),
              title: Text(u.displayName),
              subtitle: Text('@${u.username}'),
              trailing: OutlinedButton(onPressed: () => _unblock(u.id), child: const Text('Unblock')),
            ),
          );
        },
      ),
    );
  }
}

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  int _k = 0;

  Future<void> _new() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const _NewRequestDialog());
    if (ok == true && mounted) setState(() => _k++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _new, icon: const Icon(Icons.add), label: const Text('New request')),
      body: PagedList(
        key: ValueKey(_k),
        path: 'support-requests?is_reply=',
        listKey: 'supportRequest',
        empty: 'No requests yet',
        builder: (c, s) {
          final reply = str(s['reply_message']).trim();
          final replied = reply.isNotEmpty && reply != 'null';
          final t = _topicOf(str(s['subject']));
          return Card(
            elevation: 0,
            child: ListTile(
              onTap: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => SupportDetailScreen(item: s))),
              leading: CircleAvatar(child: Icon(t.icon, size: 20)),
              title: Text(str(s['request_message']), maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Row(children: [
                Icon(replied ? Icons.check_circle_rounded : Icons.schedule_rounded,
                    size: 14, color: replied ? Colors.green : Colors.orange),
                const SizedBox(width: 4),
                Flexible(child: Text('${t.label} · ${replied ? 'Replied' : 'Waiting for reply'}',
                    overflow: TextOverflow.ellipsis)),
              ]),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          );
        },
      ),
    );
  }
}

class _NewRequestDialog extends StatefulWidget {
  const _NewRequestDialog();

  @override
  State<_NewRequestDialog> createState() => _NewRequestDialogState();
}

class _NewRequestDialogState extends State<_NewRequestDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _msg = TextEditingController();
  bool _busy = false;
  String _error = '';
  String _topic = 'account';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _msg.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_msg.text.trim().isEmpty) {
      setState(() => _error = 'Please write your message');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    final r = await Api.post('support-requests', {
      'name': _name.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
      'request_message': _msg.text.trim(),
      'subject': _topic,
    });
    if (!mounted) return;
    if (r.ok) {
      Navigator.pop(context, true);
      toast(context, 'Request sent');
    } else {
      setState(() {
        _busy = false;
        _error = r.message.isEmpty ? 'Could not send' : r.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration d(String h) => InputDecoration(labelText: h, isDense: true);
    return AlertDialog(
      title: const Text('New support request'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: _topic,
              isExpanded: true,
              decoration: d('Topic'),
              items: [
                for (final t in _topics)
                  DropdownMenuItem(value: t.key, child: Row(children: [Icon(t.icon, size: 18), const SizedBox(width: 8), Expanded(child: Text(t.label, overflow: TextOverflow.ellipsis))])),
              ],
              onChanged: (v) => setState(() => _topic = v ?? _topic),
            ),
            const SizedBox(height: 8),
            TextField(controller: _name, decoration: d('Name')),
            const SizedBox(height: 8),
            TextField(controller: _email, decoration: d('Email')),
            const SizedBox(height: 8),
            TextField(controller: _phone, decoration: d('Phone')),
            const SizedBox(height: 8),
            TextField(controller: _msg, maxLines: 4, decoration: d('Message')),
            if (_error.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error, style: const TextStyle(color: Colors.red))),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _send, child: const Text('Send')),
      ],
    );
  }
}


class _Topic {
  final String key;
  final String label;
  final IconData icon;
  const _Topic(this.key, this.label, this.icon);
}

const _topics = [
  _Topic('account', 'Account & login', Icons.person_outline_rounded),
  _Topic('payment', 'Payment, wallet & coins', Icons.account_balance_wallet_outlined),
  _Topic('deposit', 'Deposit / withdraw', Icons.swap_vert_rounded),
  _Topic('subscription', 'Subscription & VIP', Icons.workspace_premium_outlined),
  _Topic('event', 'Events & tickets', Icons.confirmation_number_outlined),
  _Topic('dating', 'Dating', Icons.favorite_border_rounded),
  _Topic('chat_call', 'Chat & calls', Icons.chat_bubble_outline_rounded),
  _Topic('content', 'Posts, reels & stories', Icons.photo_library_outlined),
  _Topic('report', 'Report a user or content', Icons.flag_outlined),
  _Topic('bug', 'App problem / bug', Icons.bug_report_outlined),
  _Topic('suggestion', 'Suggestion', Icons.lightbulb_outline_rounded),
  _Topic('other', 'Other', Icons.help_outline_rounded),
];

_Topic _topicOf(String key) => _topics.firstWhere((t) => t.key == key, orElse: () => _topics.last);

/// One support request as a conversation: my message and the team's reply.
class SupportDetailScreen extends StatefulWidget {
  final Map item;
  const SupportDetailScreen({super.key, required this.item});

  @override
  State<SupportDetailScreen> createState() => _SupportDetailScreenState();
}

class _SupportDetailScreenState extends State<SupportDetailScreen> {
  late Map _it = widget.item;

  @override
  void initState() {
    super.initState();
    final id = str(_it['id']);
    if (id.isNotEmpty && id != 'null') {
      Api.get('support-requests/$id').then((r) {
        if (!mounted) return;
        final v = r.data is Map ? r.data['supportRequest'] : null;
        if (r.ok && v is Map) setState(() => _it = v);
      });
    }
  }

  String _when(dynamic ts) {
    final n = int.tryParse('$ts') ?? 0;
    if (n == 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(n * 1000);
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _bubble(String who, String text, String time, bool mine) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: mine ? cs.primary.withValues(alpha: 0.08) : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(mine ? Icons.person_rounded : Icons.support_agent_rounded, size: 18),
          const SizedBox(width: 6),
          Text(who, style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(time, style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
        ]),
        const SizedBox(height: 8),
        SelectableText(text),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _topicOf(str(_it['subject']));
    final reply = str(_it['reply_message']).trim();
    final replied = reply.isNotEmpty && reply != 'null';
    final vip = str(_it['priority']) == '1';
    return Scaffold(
      appBar: AppBar(title: const Text('Support request')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              CircleAvatar(child: Icon(t.icon)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  Wrap(spacing: 10, children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(replied ? Icons.check_circle_rounded : Icons.schedule_rounded,
                          size: 15, color: replied ? Colors.green : Colors.orange),
                      const SizedBox(width: 4),
                      Text(replied ? 'Replied' : 'Waiting for reply'),
                    ]),
                    if (vip)
                      const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.workspace_premium_rounded, size: 15, color: Colors.amber),
                        SizedBox(width: 3),
                        Text('VIP priority'),
                      ]),
                  ]),
                ]),
              ),
            ]),
            const SizedBox(height: 18),
            _bubble('You', str(_it['request_message']), _when(_it['created_at']), true),
            const SizedBox(height: 12),
            if (replied)
              _bubble('Support team', reply, _when(_it['updated_at']), false)
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.hourglass_top_rounded, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(vip
                        ? 'Thanks! As a VIP member your request is in the priority queue.'
                        : 'Thanks! Our team will reply here as soon as possible.'),
                  ),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}
