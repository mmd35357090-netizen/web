import 'package:flutter/material.dart';
import '../api.dart';
import '../chat/chat_service.dart';
import '../session.dart';
import '../widgets.dart';
import 'blocked_support_screens.dart';
import 'edit_profile_screen.dart';
import 'hashtag_screen.dart';
import 'login_screen.dart';
import 'settings_extra_screens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _toLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
  }

  Future<void> _logout(BuildContext context) async {
    await Api.post('users/logout', {});
    ChatService.instance.disconnect();
    Session.clear();
    await Api.saveToken(null);
    if (context.mounted) _toLogin(context);
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
            'Your account will be removed and you will be logged out. This cannot be undone from the app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final r = await Api.post('users/delete-account', {});
    if (!context.mounted) return;
    if (r.ok) {
      ChatService.instance.disconnect();
      Session.clear();
      await Api.saveToken(null);
      if (context.mounted) _toLogin(context);
    } else {
      toast(context, r.message.isEmpty ? 'Could not delete account' : r.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(children: [
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Edit profile'),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const EditProfileScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_border_rounded),
              title: const Text('Saved posts'),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const SavedPostsScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline_rounded),
              title: const Text('Change password'),
              onTap: () => showDialog(context: context, builder: (_) => const _PasswordDialog()),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy & notifications'),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_outlined),
              title: const Text('Follow requests'),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const FollowRequestsScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline_rounded),
              title: const Text('FAQ'),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const FaqScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded),
              title: const Text('Blocked users'),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const BlockedUsersScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.support_agent_rounded),
              title: const Text('Support'),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const SupportScreen())),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Log out'),
              onTap: () => _logout(context),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Delete account', style: TextStyle(color: Colors.red)),
              onTap: () => _delete(context),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_new.text.length < 6) {
      setState(() => _error = 'New password must be at least 6 characters');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    final r = await Api.post('users/update-password', {
      'old_password': _old.text,
      'password': _new.text,
      'confirm_password': _new.text,
    });
    if (!mounted) return;
    if (r.ok) {
      Navigator.pop(context);
      toast(context, 'Password changed');
    } else {
      setState(() {
        _busy = false;
        _error = r.message.isEmpty ? 'Could not change password' : r.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
            controller: _old,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password')),
        TextField(
            controller: _new,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password')),
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_error, style: const TextStyle(color: Colors.red)),
          ),
      ]),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
