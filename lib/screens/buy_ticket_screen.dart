import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets.dart';
import 'events_screen.dart';
import 'paged_list.dart';

/// Buy tickets with the wallet balance. The server recalculates the price,
/// so what is shown here is only a preview.
class BuyTicketScreen extends StatefulWidget {
  final EventItem event;
  const BuyTicketScreen({super.key, required this.event});

  @override
  State<BuyTicketScreen> createState() => _BuyTicketScreenState();
}

class _BuyTicketScreenState extends State<BuyTicketScreen> {
  bool _loading = true;
  bool _busy = false;
  double _balance = 0;
  List<Map> _coupons = [];
  int _sel = -1;
  int _qty = 1;
  Map? _coupon;

  List<Map<String, String>> get _tickets => widget.event.tickets;
  Map<String, String>? get _ticket => _sel < 0 ? null : _tickets[_sel];
  double get _price => double.tryParse(_ticket?['price'] ?? '') ?? 0;
  int get _left => int.tryParse(_ticket?['left'] ?? '') ?? 999;
  double get _subtotal => _price * _qty;
  double get _discount {
    if (_coupon == null) return 0;
    final d = double.tryParse('${_coupon!['coupon_value']}') ?? 0;
    return d > _subtotal ? _subtotal : d;
  }

  double get _total => (_subtotal - _discount).clamp(0, double.infinity).toDouble();

  @override
  void initState() {
    super.initState();
    // pick the first ticket that is still available
    for (var i = 0; i < _tickets.length; i++) {
      if ((int.tryParse(_tickets[i]['left'] ?? '') ?? 1) > 0) {
        _sel = i;
        break;
      }
    }
    _load();
  }

  Future<void> _load() async {
    final me = await Api.get('users/profile');
    final cp = await Api.get('events/coupon');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (me.data is Map && me.data['user'] is Map) {
        _balance = double.tryParse('${(me.data['user'] as Map)['available_balance']}') ?? 0;
      }
      final l = cp.data is Map ? cp.data['coupon'] : null;
      _coupons = l is List ? l.whereType<Map>().toList() : [];
    });
  }

  String _m(double v) => '\$${v.toStringAsFixed(2)}';

  void _pickCoupon(Map c) {
    final min = double.tryParse('${c['minimum_order_price']}') ?? 0;
    if (_subtotal < min) {
      toast(context, 'Minimum order for this coupon is ${_m(min)}');
      return;
    }
    setState(() => _coupon = _coupon == c ? null : c);
  }

  Future<void> _buy() async {
    final t = _ticket;
    if (t == null) return;
    if (_total > _balance + 0.0001) {
      toast(context, 'Not enough balance. Add money in Wallet first.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirm purchase'),
        content: Text('$_qty × ${t['name']}\nTotal ${_m(_total)} from your wallet balance.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(_total == 0 ? 'Get ticket' : 'Pay ${_m(_total)}')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final r = await Api.post('events/buy-ticket', {
      'event_id': '${widget.event.id}',
      'event_ticket_id': t['id'] ?? '',
      'ticket_qty': '$_qty',
      'ticket_amount': _subtotal.toStringAsFixed(2),
      'paid_amount': _total.toStringAsFixed(2),
      'coupon': _coupon == null ? '' : '${_coupon!['code']}',
      'coupon_discount_value': _discount.toStringAsFixed(2),
      'payments': _total > 0
          ? [
              {'payment_mode': 3, 'amount': _total, 'transaction_id': 'wallet-${DateTime.now().millisecondsSinceEpoch}'}
            ]
          : [],
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.ok) {
      toast(context, 'Ticket booked');
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MyTicketsScreen()));
    } else {
      toast(context, r.message.isEmpty ? 'Could not book the ticket' : r.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buy ticket')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  Text(widget.event.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  const Text('Ticket type', style: TextStyle(fontWeight: FontWeight.w700)),
                  for (var i = 0; i < _tickets.length; i++)
                    RadioListTile<int>(
                      contentPadding: EdgeInsets.zero,
                      value: i,
                      groupValue: _sel,
                      onChanged: (int.tryParse(_tickets[i]['left'] ?? '') ?? 1) <= 0
                          ? null
                          : (v) => setState(() {
                                _sel = v ?? _sel;
                                _qty = 1;
                                _coupon = null;
                              }),
                      title: Text(_tickets[i]['name'] ?? ''),
                      subtitle: Text((int.tryParse(_tickets[i]['left'] ?? '') ?? 1) <= 0
                          ? 'Sold out'
                          : '${_m(double.tryParse(_tickets[i]['price'] ?? '') ?? 0)}'),
                    ),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(
                        onPressed: _qty > 1
                            ? () => setState(() {
                                  _qty--;
                                  if (_coupon != null && _subtotal < (double.tryParse('${_coupon!['minimum_order_price']}') ?? 0)) _coupon = null;
                                })
                            : null,
                        icon: const Icon(Icons.remove_circle_outline)),
                    Text('$_qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    IconButton(
                        onPressed: _qty < _left && _qty < 10 ? () => setState(() => _qty++) : null,
                        icon: const Icon(Icons.add_circle_outline)),
                  ]),
                  if (_coupons.isNotEmpty && _price > 0) ...[
                    const Divider(height: 28),
                    const Text('Coupons', style: TextStyle(fontWeight: FontWeight.w700)),
                    for (final c in _coupons)
                      Card(
                        elevation: 0,
                        color: _coupon == c ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : null,
                        child: ListTile(
                          leading: const Icon(Icons.local_offer_outlined),
                          title: Text('${c['title']} (${c['code']})'),
                          subtitle: Text('Save ${_m(double.tryParse('${c['coupon_value']}') ?? 0)} · min ${_m(double.tryParse('${c['minimum_order_price']}') ?? 0)}'),
                          trailing: _coupon == c ? const Icon(Icons.check_circle_rounded) : null,
                          onTap: () => _pickCoupon(c),
                        ),
                      ),
                  ],
                  const Divider(height: 28),
                  _row('Tickets', _m(_subtotal)),
                  if (_discount > 0) _row('Coupon', '-${_m(_discount)}'),
                  _row('Total', _m(_total), bold: true),
                  _row('Wallet balance', _m(_balance)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy || _ticket == null ? null : _buy,
                    child: Text(_busy ? 'Booking...' : (_total == 0 ? 'Get free ticket' : 'Pay ${_m(_total)} from wallet')),
                  ),
                  if (_total > _balance + 0.0001)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Your balance is too low. Add money in Wallet.', style: TextStyle(color: Colors.red)),
                    ),
                ]),
              ),
            ),
    );
  }

  Widget _row(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text(a, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w400)),
          const Spacer(),
          Text(b, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w400)),
        ]),
      );
}
