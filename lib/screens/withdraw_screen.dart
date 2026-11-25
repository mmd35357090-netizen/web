import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';
import '../widgets.dart';
import 'payout_methods_screen.dart';

double _d(dynamic v) => double.tryParse('$v') ?? 0;

String _plain(double v) => v.toString().replaceAll(RegExp(r'\.0+$'), '');

/// One way of getting paid. Rate and charges are set by the admin and come from the server.
class _Option {
  final String method;
  final String title;
  final String currencyCode;
  final String currencySymbol;
  final int decimals;
  final double rate;
  final double feePercent;
  final double feeFixedUsd;
  final double minUsd;
  final double maxUsd;
  final String note;
  final bool hasAccount;
  final String accountMasked;

  _Option(Map j)
      : method = '${j['method']}',
        title = '${j['title']}',
        currencyCode = '${j['currency_code']}',
        currencySymbol = '${j['currency_symbol']}',
        decimals = int.tryParse('${j['currency_decimals']}') ?? 2,
        rate = _d(j['rate']),
        feePercent = _d(j['fee_percent']),
        feeFixedUsd = _d(j['fee_fixed_usd']),
        minUsd = _d(j['min_usd']),
        maxUsd = _d(j['max_usd']),
        note = '${j['note'] ?? ''}'.replaceAll('null', ''),
        hasAccount = '${j['has_account']}' == '1',
        accountMasked = '${j['account_masked'] ?? ''}'.replaceAll('null', '');

  double feeFor(double amount) => double.parse((amount * feePercent / 100 + feeFixedUsd).toStringAsFixed(2));
  double netUsd(double amount) => double.parse((amount - feeFor(amount)).toStringAsFixed(2));
  double netLocal(double amount) => double.parse((netUsd(amount) * rate).toStringAsFixed(decimals));

  String get rateText => rate == 1 && currencyCode.toUpperCase().startsWith('U')
      ? currencyCode
      : '1 USD = ${_plain(rate)} $currencyCode';

  String get feeText => [
        if (feePercent > 0) '${_plain(feePercent)}%',
        if (feeFixedUsd > 0) '\$${feeFixedUsd.toStringAsFixed(2)}',
      ].join(' + ');
}

/// Withdraw: choose an amount, choose a method, see exactly what you will receive, then confirm.
class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final TextEditingController _amount = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  String _error = '';
  double _balance = 0;
  bool _blocked = false;
  String _blockMessage = '';
  List<_Option> _options = [];
  String? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await Api.get('withdraw-options');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok && r.data is Map) {
        final d = r.data as Map;
        _error = '';
        _balance = _d(d['balance']);
        _blocked = '${d['blocked']}' == '1';
        _blockMessage = '${d['block_message'] ?? ''}'.replaceAll('null', '');
        _options = ((d['withdrawMethods'] ?? []) as List).map((e) => _Option(e as Map)).toList();
        if (_options.isNotEmpty && !_options.any((o) => o.method == _selected)) {
          _selected = _options.firstWhere((o) => o.hasAccount, orElse: () => _options.first).method;
        }
      } else {
        _error = r.message.isEmpty ? 'Could not load withdraw options' : r.message;
      }
    });
  }

  _Option? get _opt {
    for (final o in _options) {
      if (o.method == _selected) return o;
    }
    return null;
  }

  double get _value => double.tryParse(_amount.text.trim()) ?? 0;

  /// null when the amount can be sent
  String? _problem() {
    final o = _opt;
    final a = _value;
    if (o == null) return 'Choose a method';
    if (!o.hasAccount) return 'Add your ${o.title} account first';
    if (a <= 0) return 'Enter an amount';
    if (a + 0.0001 < o.minUsd) return 'Minimum is \$${o.minUsd.toStringAsFixed(2)}';
    if (a > o.maxUsd + 0.0001) return 'Maximum is \$${o.maxUsd.toStringAsFixed(2)}';
    if (a > _balance + 0.004) return 'More than your balance';
    if (o.netUsd(a) <= 0) return 'Too small to cover the charge';
    return null;
  }

  Future<void> _addAccount() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PayoutMethodsScreen()));
    if (mounted) _load();
  }

  Future<void> _submit() async {
    final o = _opt;
    if (o == null) return;
    final a = _value;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirm withdrawal'),
        content: Text('Withdraw \$${a.toStringAsFixed(2)} to ${o.title} (${o.accountMasked})?\n\n'
            'Charge: \$${o.feeFor(a).toStringAsFixed(2)}\n'
            'You will receive: ${o.currencySymbol}${o.netLocal(a).toStringAsFixed(o.decimals)} ${o.currencyCode}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (yes != true) return;
    setState(() => _busy = true);
    final r = await Api.post('withdraw-options/request', {'method': o.method, 'amount': a.toStringAsFixed(2)});
    if (!mounted) return;
    setState(() => _busy = false);
    final msg = (r.data is Map && r.data['message'] != null) ? '${r.data['message']}' : r.message;
    toast(context, msg.isEmpty ? (r.ok ? 'Withdrawal requested' : 'Could not send the request') : msg);
    if (r.ok) {
      Navigator.of(context).pop(true);
    } else {
      _load();
    }
  }

  Widget _methodTile(_Option m) {
    final cs = Theme.of(context).colorScheme;
    final sel = m.method == _selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _selected = m.method),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel ? cs.primary : Colors.grey.withValues(alpha: 0.35), width: sel ? 2 : 1),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, color: sel ? cs.primary : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 3),
                Text(m.rateText, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                Text(
                  'Charge: ${m.feeText.isEmpty ? 'none' : m.feeText}  ·  \$${m.minUsd.toStringAsFixed(2)} – \$${m.maxUsd.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12.5),
                ),
                const SizedBox(height: 3),
                Text(
                  m.hasAccount ? m.accountMasked : 'No account added yet',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: m.hasAccount ? Colors.green.shade700 : Colors.orange.shade800),
                ),
                if (m.note.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(m.note, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _summary(_Option o, double a) {
    final cs = Theme.of(context).colorScheme;
    Widget row(String l, String v, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(l, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
            Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
          ]),
        );
    final valid = a > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        row('Amount', '\$${a.toStringAsFixed(2)}'),
        row('Charge', valid ? '- \$${o.feeFor(a).toStringAsFixed(2)}' : '-'),
        const Divider(),
        row(
          'You receive',
          valid && o.netUsd(a) > 0
              ? '${o.currencySymbol}${o.netLocal(a).toStringAsFixed(o.decimals)} ${o.currencyCode}'
              : '-',
          bold: true,
        ),
      ]),
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
            TextButton(onPressed: _load, child: const Text('Retry')),
          ]),
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    final o = _opt;
    final a = _value;
    final problem = _problem();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: cs.primary),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Available balance',
              style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('\$${(_balance < 0.005 ? 0 : _balance).toStringAsFixed(2)}',
              style: TextStyle(color: cs.onPrimary, fontSize: 28, fontWeight: FontWeight.w800)),
        ]),
      ),
      const SizedBox(height: 14),
      if (_blocked)
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1E0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE07B00).withValues(alpha: 0.5)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.lock_clock_rounded, color: Color(0xFFE07B00)),
            const SizedBox(width: 10),
            Expanded(child: Text(_blockMessage, style: const TextStyle(color: Colors.black87))),
          ]),
        ),
      const Text('Amount (USD)', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      TextField(
        controller: _amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,7}(\.\d{0,2})?'))],
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          prefixText: '\$ ',
          hintText: '0.00',
          suffix: TextButton(
            onPressed: () {
              final cap = o == null ? _balance : (_balance < o.maxUsd ? _balance : o.maxUsd);
              _amount.text = (cap < 0 ? 0 : cap).toStringAsFixed(2);
              setState(() {});
            },
            child: const Text('Max'),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      const SizedBox(height: 18),
      const Text('Receive with', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      if (_options.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('Withdrawals are not open right now. Please try later.'),
        )
      else
        ..._options.map(_methodTile),
      if (o != null) ...[
        const SizedBox(height: 4),
        _summary(o, a),
      ],
      const SizedBox(height: 18),
      if (o != null && !o.hasAccount)
        FilledButton(onPressed: _addAccount, child: Text('Add ${o.title} account'))
      else
        FilledButton(
          onPressed: (problem == null && !_blocked && !_busy) ? _submit : null,
          child: Text(_busy ? 'Please wait…' : (problem ?? 'Withdraw')),
        ),
      const SizedBox(height: 10),
      TextButton.icon(
        onPressed: _addAccount,
        icon: const Icon(Icons.settings_outlined, size: 18),
        label: const Text('Manage payout methods'),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Withdraw')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: _body()),
      ),
    );
  }
}
