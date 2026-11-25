import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../app_only.dart';
import '../widgets.dart';
import 'paged_list.dart';
import 'payout_methods_screen.dart';
import 'watch_earn_screen.dart';
import 'withdraw_screen.dart';

String _money(dynamic v) => '\$${(double.tryParse('$v') ?? 0).toStringAsFixed(2)}';

/// Small amounts keep their decimals (0.0001 stays 0.0001, not $0.00).
String _tiny(double v) {
  var t = v.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '');
  if (t.endsWith('.')) t = t.substring(0, t.length - 1);
  final dot = t.indexOf('.');
  if (dot >= 0 && t.length - dot - 1 < 2) t = double.parse(t).toStringAsFixed(2);
  return '\$$t';
}

String _typeName(int t) {
  switch (t) {
    case 1:
      return 'Coin package';
    case 2:
      return 'Award';
    case 3:
      return 'Withdrawal';
    case 4:
      return 'Withdrawal refund';
    case 5:
      return 'TV subscription';
    case 6:
      return 'Gift';
    case 7:
      return 'Coins converted to money';
    case 8:
      return 'Event ticket';
    case 9:
      return 'Event ticket refund';
    case 10:
      return 'Dating subscription';
    case 11:
      return 'Promotion';
    case 12:
      return 'Promotion refund';
    case 14:
      return 'Streaming award';
    case 15:
      return 'Fundraising';
    case 16:
      return 'Featured ad';
    case 17:
      return 'Banner ad';
    case 18:
      return 'Coin transfer';
    case 19:
      return 'Admin update';
    case 20:
      return 'Subscription';
    case 21:
      return 'Deposit';
    case 22:
      return 'Ad reward';
    case 23:
      return 'Competition fee';
    case 24:
      return 'Creator pool';
  }
  return 'Transaction';
}

String _date(dynamic v) {
  final n = int.tryParse('$v');
  if (n == null || n == 0) return '';
  return DateFormat('d MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(n * 1000));
}

/// "· 1,200 BDT" for withdrawals made with the new method list; empty for old ones.
String _receiveNote(Map p) {
  final cc = '${p['currency_code'] ?? ''}'.replaceAll('null', '');
  final nl = '${p['net_local'] ?? ''}'.replaceAll('null', '');
  if (cc.isEmpty || nl.isEmpty) return '';
  final v = double.tryParse(nl);
  return ' · ${v == null ? nl : v.toString().replaceAll(RegExp(r'\.0+$'), '')} $cc';
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _loading = true;
  int _coins = 0;
  double _balance = 0;
  double _perCoin = 0;
  int _minRedeem = 0;
  int _viewCoins = 0;
  int _k = 0; // refreshes the history lists

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await Api.get('users/profile');
    final st = await Api.get('settings?expand=featureList');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (me.data is Map && me.data['user'] is Map) {
        final u = me.data['user'] as Map;
        _coins = int.tryParse('${u['available_coin']}') ?? 0;
        _balance = double.tryParse('${u['available_balance']}') ?? 0;
      }
      if (st.data is Map && st.data['setting'] is Map) {
        final s = st.data['setting'] as Map;
        _perCoin = double.tryParse('${s['per_coin_value']}') ?? 0;
        _minRedeem = int.tryParse('${s['min_coin_redeem']}') ?? 0;
        _viewCoins = int.tryParse('${s['each_view_coin']}') ?? 0;
      }
      _k++;
    });
  }

  Future<void> _redeem() async {
    final ctrl = TextEditingController();
    final coins = await showDialog<int>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) {
        final n = int.tryParse(ctrl.text) ?? 0;
        final est = (n * _perCoin * 100).floor() / 100;
        return AlertDialog(
          title: const Text('Convert coins to money'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setD(() {}),
              decoration: InputDecoration(labelText: 'Coins', helperText: 'You have $_coins. Minimum $_minRedeem.'),
            ),
            const SizedBox(height: 10),
            Text('You will get about ${_money(est)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Only coins you earned (gifts, subscriptions and so on) can be converted. Coins you bought or got as a bonus can be spent in the app only.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            FilledButton(onPressed: n > 0 ? () => Navigator.pop(c, n) : null, child: const Text('Convert')),
          ],
        );
      }),
    );
    ctrl.dispose();
    if (coins == null) return;
    final r = await Api.post('payments/redeem-coin', {'redeem_coin': '$coins'});
    if (!mounted) return;
    toast(context, r.ok ? 'Converted' : (r.message.isEmpty ? 'Could not convert' : r.message));
    if (r.ok) _load();
  }

  Future<void> _openWithdraw() async {
    final r = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const WithdrawScreen()));
    if (r == true) _load();
  }

  Future<void> _openPayout() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PayoutMethodsScreen()));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Wallet & earnings'),
          bottom: const TabBar(tabs: [Tab(text: 'Overview'), Tab(text: 'Transactions'), Tab(text: 'Withdrawals')]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(padding: const EdgeInsets.all(16), children: [
                        Row(children: [
                          Expanded(child: _stat(cs, Icons.monetization_on_outlined, '$_coins', 'Coins')),
                          const SizedBox(width: 12),
                          Expanded(child: _stat(cs, Icons.account_balance_wallet_outlined, _money(_balance), 'Balance')),
                        ]),
                        const SizedBox(height: 16),
                        Card(
                          child: Column(children: [
                            ListTile(
                              leading: const Icon(Icons.smart_display_outlined),
                              title: const Text('Watch & Earn'),
                              subtitle: Text(_viewCoins > 0 ? 'Watch a sponsored video, earn $_viewCoins ${_viewCoins == 1 ? 'coin' : 'coins'}' : 'Watch a sponsored video to earn coins'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () async {
                                final r = await Navigator.of(context)
                                    .push<bool>(MaterialPageRoute(builder: (_) => const WatchEarnScreen()));
                                if (r == true) _load();
                              },
                            ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(Icons.currency_exchange_rounded),
                              title: const Text('Convert coins to money'),
                              subtitle: Text(_perCoin > 0 ? '1 coin = ${_tiny(_perCoin)}' : 'Turn earned coins into balance'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: _redeem,
                            ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(Icons.payments_outlined),
                              title: const Text('Withdraw money'),
                              subtitle: const Text('Choose an amount and how to receive it'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: _openWithdraw,
                            ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(Icons.account_balance_outlined),
                              title: const Text('Payout methods'),
                              subtitle: const Text('PayPal, bKash, Nagad, USDT, Binance'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: _openPayout,
                            ),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        const AppOnlyNote('Buying coins is done in the mobile app (Google Play / App Store).'),
                        const SizedBox(height: 8),
                        const Text(
                          'You earn when people send you gifts, subscribe to you or watch your live videos, and by watching sponsored videos.',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ]),
                    ),
                  ),
                ),
                PagedList(
                  key: ValueKey('t$_k'),
                  path: 'payments/payment-history?month=2000-08,2050-09',
                  listKey: 'payment',
                  empty: 'No transactions yet',
                  builder: (c, p) {
                    final credit = '${p['transaction_type']}' == '1';
                    final isCoin = '${p['type']}' == '2';
                    final amt = isCoin ? '${p['coin']} coins' : _money(p['amount']);
                    return Card(
                      child: ListTile(
                        leading: Icon(credit ? Icons.south_west_rounded : Icons.north_east_rounded,
                            color: credit ? Colors.green : Colors.redAccent),
                        title: Text(_typeName(int.tryParse('${p['payment_type']}') ?? 0)),
                        subtitle: Text(_date(p['created_at'])),
                        trailing: Text('${credit ? '+' : '-'}$amt',
                            style: TextStyle(fontWeight: FontWeight.w700, color: credit ? Colors.green : Colors.redAccent)),
                      ),
                    );
                  },
                ),
                PagedList(
                  key: ValueKey('w$_k'),
                  path: 'payments/withdrawal-history?x=1',
                  listKey: 'payment',
                  empty: 'No withdrawal requests yet',
                  builder: (c, p) {
                    final st = int.tryParse('${p['status']}') ?? 0;
                    final label = st == 1 ? 'Paid' : (st == 2 ? 'Rejected' : 'Pending');
                    final color = st == 1 ? Colors.green : (st == 2 ? Colors.redAccent : Colors.orange);
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.payments_outlined),
                        title: Text(_money(p['amount'])),
                        subtitle: Text(_date(p['created_at']) + _receiveNote(p)),
                        trailing: Chip(
                          label: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    );
                  },
                ),
              ]),
      ),
    );
  }

  Widget _stat(ColorScheme cs, IconData icon, String value, String label) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
          child: Column(children: [
            Icon(icon, color: cs.primary, size: 28),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: Colors.black54)),
          ]),
        ),
      );
}
