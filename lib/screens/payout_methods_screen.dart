import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';
import '../widgets.dart';

class _Meta {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final String fieldLabel;
  final String hint;
  final TextInputType keyboard;
  const _Meta(this.key, this.label, this.icon, this.color, this.fieldLabel, this.hint, this.keyboard);
}

const List<_Meta> _metas = [
  _Meta('paypal', 'PayPal', Icons.payments_rounded, Color(0xFF0070BA), 'PayPal email', 'name@example.com',
      TextInputType.emailAddress),
  _Meta('bkash', 'bKash', Icons.phone_android_rounded, Color(0xFFE2136E), 'bKash number (Personal)', '01XXXXXXXXX',
      TextInputType.phone),
  _Meta('nagad', 'Nagad', Icons.phone_android_rounded, Color(0xFFF6921E), 'Nagad number (Personal)', '01XXXXXXXXX',
      TextInputType.phone),
  _Meta('usdt', 'USDT', Icons.currency_bitcoin_rounded, Color(0xFF26A17B), 'USDT wallet address', 'Paste your address',
      TextInputType.text),
  _Meta('binance', 'Binance UID', Icons.account_balance_wallet_rounded, Color(0xFFD9A400), 'Binance Pay ID / UID',
      'e.g. 123456789', TextInputType.number),
];

_Meta _metaOf(String key) => _metas.firstWhere((m) => m.key == key, orElse: () => _metas.first);

class _Method {
  final int id;
  final String method;
  final String label;
  final String network;
  final String accountMasked;
  final bool isDefault;

  _Method(Map j)
      : id = int.tryParse('${j['id']}') ?? 0,
        method = '${j['method']}',
        label = '${j['label']}',
        network = '${j['network'] ?? ''}'.replaceAll('null', ''),
        accountMasked = '${j['account_masked']}',
        isDefault = '${j['is_default']}' == '1';
}

class _Res {
  final bool ok;
  final String message;
  _Res(this.ok, this.message);
}

Future<_Res> _post(String path, Map<String, dynamic> body) async {
  final r = await Api.post('payout-methods/$path', body);
  final msg = (r.data is Map && r.data['message'] != null) ? '${r.data['message']}' : r.message;
  return _Res(r.ok, msg);
}

/// Payout methods: PayPal, bKash, Nagad, USDT, Binance UID.
/// Every change needs an email code and puts withdrawals on hold for a few days.
class PayoutMethodsScreen extends StatefulWidget {
  const PayoutMethodsScreen({super.key});

  @override
  State<PayoutMethodsScreen> createState() => _PayoutMethodsScreenState();
}

class _PayoutMethodsScreenState extends State<PayoutMethodsScreen> {
  bool _loading = true;
  String _error = '';
  List<_Method> _methods = [];
  bool _holdActive = false;
  String _holdText = '';
  int _holdUntil = 0;
  int _serverTime = 0;
  int _holdDays = 7;
  String _emailMasked = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Api.get('payout-methods');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok && r.data is Map) {
        final d = r.data as Map;
        _error = '';
        _methods = ((d['payoutMethods'] ?? []) as List).map((e) => _Method(e as Map)).toList();
        _holdActive = '${d['hold_active']}' == '1';
        _holdText = '${d['hold_text'] ?? ''}'.replaceAll('null', '');
        _holdUntil = int.tryParse('${d['hold_until']}') ?? 0;
        _serverTime = int.tryParse('${d['server_time']}') ?? 0;
        _holdDays = int.tryParse('${d['hold_days']}') ?? 7;
        _emailMasked = '${d['email_masked'] ?? ''}'.replaceAll('null', '');
      } else {
        _error = r.message.isEmpty ? 'Could not load payout methods' : r.message;
      }
    });
  }

  /// email code -> action
  Future<void> _secure(Future<_Res> Function(String otp) action) async {
    final sent = await _post('send-otp', {});
    if (!mounted) return;
    if (!sent.ok) {
      toast(context, sent.message.isEmpty ? 'Could not send the code' : sent.message);
      return;
    }
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OtpDialog(email: _emailMasked),
    );
    if (code == null || !mounted) return;
    final r = await action(code);
    if (!mounted) return;
    toast(context, r.message.isEmpty ? (r.ok ? 'Done' : 'Failed') : r.message);
    if (r.ok) await _load();
  }

  Future<void> _openEditor({String? method}) async {
    final res = await showModalBottomSheet<_EditorResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _EditorSheet(initialMethod: method, hasOthers: _methods.isNotEmpty, holdDays: _holdDays),
    );
    if (res == null) return;
    await _secure((otp) => _post('save', {
          'method': res.method,
          'account': res.account,
          'network': res.network ?? '',
          'otp': otp,
          'make_default': res.makeDefault ? 1 : 0,
        }));
  }

  Future<void> _confirm(String title, String text, VoidCallback onYes) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Continue')),
        ],
      ),
    );
    if (yes == true) onYes();
  }

  Widget _holdBanner() {
    final cs = Theme.of(context).colorScheme;
    if (_holdActive) {
      final left = ((_holdUntil - _serverTime) / 86400).ceil();
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1E0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE07B00).withValues(alpha: 0.5)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.lock_clock_rounded, color: Color(0xFFE07B00)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Withdrawals are on hold',
                  style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black87)),
              const SizedBox(height: 3),
              Text(
                'You changed a payout method. For your security you can withdraw again on $_holdText ($left day${left == 1 ? '' : 's'} left).',
                style: const TextStyle(fontSize: 13, height: 1.35, color: Colors.black87),
              ),
            ]),
          ),
        ]),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.verified_user_rounded, color: cs.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Your money is protected. Any change to a payout method needs an email code and puts withdrawals on hold for $_holdDays days.',
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
        ),
      ]),
    );
  }

  Widget _card(_Method m) {
    final cs = Theme.of(context).colorScheme;
    final meta = _metaOf(m.method);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: m.isDefault ? cs.primary.withValues(alpha: 0.6) : Colors.grey.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: meta.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(13)),
            child: Icon(meta.icon, color: meta.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
                Text(m.label + (m.network.isNotEmpty ? ' · ${m.network}' : ''),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                if (m.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration:
                        BoxDecoration(color: cs.primary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                    child: Text('Default', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary)),
                  ),
              ]),
              const SizedBox(height: 3),
              Text(m.accountMasked, style: const TextStyle(fontSize: 13.5, color: Colors.black54)),
            ]),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') {
                _openEditor(method: m.method);
              } else if (v == 'default') {
                _confirm(
                  'Make default?',
                  'Withdrawals will go to ${m.label}. This puts withdrawals on hold for $_holdDays days.',
                  () => _secure((otp) => _post('make-default', {'id': m.id, 'otp': otp})),
                );
              } else if (v == 'remove') {
                _confirm(
                  'Remove ${m.label}?',
                  'This puts withdrawals on hold for $_holdDays days.',
                  () => _secure((otp) => _post('remove', {'id': m.id, 'otp': otp})),
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Replace account')),
              if (!m.isDefault) const PopupMenuItem(value: 'default', child: Text('Make default')),
              const PopupMenuItem(value: 'remove', child: Text('Remove')),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() => _loading = true);
                _load();
              },
              child: const Text('Retry'),
            ),
          ]),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
        _holdBanner(),
        const SizedBox(height: 20),
        const Text('YOUR PAYOUT METHODS',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: Colors.black54)),
        const SizedBox(height: 10),
        if (_methods.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Text('No payout method yet.\nAdd one to receive your earnings.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
          ),
        for (final m in _methods) _card(m),
        const SizedBox(height: 6),
        FilledButton(onPressed: () => _openEditor(), child: const Text('Add payout method')),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payout methods')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: _body()),
      ),
    );
  }
}

// =================== editor sheet (collects the details) ===================
class _EditorResult {
  final String method;
  final String account;
  final String? network;
  final bool makeDefault;
  _EditorResult(this.method, this.account, this.network, this.makeDefault);
}

class _EditorSheet extends StatefulWidget {
  final String? initialMethod;
  final bool hasOthers;
  final int holdDays;
  const _EditorSheet({this.initialMethod, required this.hasOthers, required this.holdDays});

  @override
  State<_EditorSheet> createState() => _EditorSheetState();
}

class _EditorSheetState extends State<_EditorSheet> {
  late String method = widget.initialMethod ?? 'bkash';
  String network = 'TRC20';
  bool makeDefault = false;
  final account = TextEditingController();
  final confirmAccount = TextEditingController();
  String? error;

  @override
  void dispose() {
    account.dispose();
    confirmAccount.dispose();
    super.dispose();
  }

  void _submit() {
    final a = account.text.trim();
    if (a.isEmpty) {
      setState(() => error = 'Please enter the account details.');
      return;
    }
    if (a != confirmAccount.text.trim()) {
      setState(() => error = 'The two entries do not match.');
      return;
    }
    Navigator.pop(context, _EditorResult(method, a, method == 'usdt' ? network : null, makeDefault));
  }

  @override
  Widget build(BuildContext context) {
    final meta = _metaOf(method);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final digitsOnly = method == 'binance' ? [FilteringTextInputFormatter.digitsOnly] : null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottom),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.initialMethod == null ? 'Add payout method' : 'Replace ${meta.label}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              if (widget.initialMethod == null)
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final m in _metas)
                    ChoiceChip(
                      avatar: Icon(m.icon, size: 16, color: method == m.key ? Colors.white : m.color),
                      label: Text(m.label),
                      selected: method == m.key,
                      showCheckmark: false,
                      selectedColor: m.color,
                      labelStyle: TextStyle(color: method == m.key ? Colors.white : null),
                      onSelected: (_) => setState(() {
                        method = m.key;
                        error = null;
                      }),
                    ),
                ]),
              if (method == 'usdt') ...[
                const SizedBox(height: 14),
                Wrap(spacing: 8, children: [
                  for (final n in ['TRC20', 'BEP20', 'ERC20'])
                    ChoiceChip(
                      label: Text(n == 'TRC20' ? 'TRC20 (cheapest)' : n),
                      selected: network == n,
                      onSelected: (_) => setState(() => network = n),
                    ),
                ]),
                const SizedBox(height: 6),
                const Text('Send only on the network you pick. A wrong network loses the money.',
                    style: TextStyle(fontSize: 12, color: Colors.red)),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: account,
                keyboardType: meta.keyboard,
                inputFormatters: digitsOnly,
                decoration: InputDecoration(
                    labelText: meta.fieldLabel, hintText: meta.hint, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmAccount,
                keyboardType: meta.keyboard,
                inputFormatters: digitsOnly,
                decoration: InputDecoration(
                    labelText: 'Type it again to confirm', hintText: meta.hint, border: const OutlineInputBorder()),
              ),
              if (widget.hasOthers)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: makeDefault,
                  onChanged: (v) => setState(() => makeDefault = v),
                  title: const Text('Use as my default method'),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFF1E0), borderRadius: BorderRadius.circular(12)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFE07B00)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'After you save, withdrawals are on hold for ${widget.holdDays} days. Double-check the details: payments cannot be taken back.',
                      style: const TextStyle(fontSize: 12.5, height: 1.35, color: Colors.black87),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: _submit, child: const Text('Continue'))),
            ]),
          ),
        ),
      ),
    );
  }
}

// =================== email code dialog ===================
class _OtpDialog extends StatefulWidget {
  final String email;
  const _OtpDialog({required this.email});

  @override
  State<_OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends State<_OtpDialog> {
  final code = TextEditingController();
  int wait = 60;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => wait = wait > 0 ? wait - 1 : 0);
      if (wait == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    code.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    final r = await _post('send-otp', {});
    if (!mounted) return;
    toast(context, r.message.isEmpty ? (r.ok ? 'Code sent' : 'Could not send the code') : r.message);
    if (r.ok) {
      setState(() => wait = 60);
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter the email code'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('We sent a 6-digit code to ${widget.email}.'),
        const SizedBox(height: 14),
        TextField(
          controller: code,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(counterText: '', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: wait == 0 ? _resend : null,
            child: Text(wait == 0 ? 'Send again' : 'Send again in ${wait}s'),
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (code.text.trim().length == 6) Navigator.pop(context, code.text.trim());
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
