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
          final reply = str(s['reply_message']);
          return Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(str(s['request_message']), style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (reply.isNotEmpty && reply != 'null')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('Reply: $reply'),
                  )
                else
                  const Text('Waiting for reply', style: TextStyle(color: Colors.black45, fontSize: 12)),
              ]),
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
