import 'package:flutter/material.dart';
import '../models.dart';
import '../session.dart';
import '../widgets.dart';
import 'paged_list.dart';

class ReceivedGiftsScreen extends StatelessWidget {
  const ReceivedGiftsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gifts received')),
      body: PagedList(
        path: 'gifts/recieved-gift?expand=giftDetail,senderDetail&send_on_type=&live_call_id=&post_id=',
        listKey: 'gift',
        empty: 'No gifts yet',
        builder: (c, g) {
          final gift = g['giftDetail'] is Map ? g['giftDetail'] as Map : {};
          final sd = g['senderDetail'];
          final img = str(gift['imageUrl']);
          return Card(
            elevation: 0,
            child: ListTile(
              leading: SizedBox(
                width: 48,
                height: 48,
                child: img.isEmpty || img == 'null'
                    ? const Icon(Icons.card_giftcard_rounded, size: 32)
                    : netImage(img, width: 48, height: 48, fit: BoxFit.contain),
              ),
              title: Text(str(gift['name'])),
              subtitle: Text(sd == null ? '' : 'From ${AppUser.fromJson(sd).displayName}'),
              trailing: Text('${str(gift['coin'])} coins', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          );
        },
      ),
    );
  }
}

/// [mine] = true: people I subscribed to. false: people subscribed to me.
class SubscriptionsScreen extends StatefulWidget {
  final bool mine;
  const SubscriptionsScreen({super.key, required this.mine});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  int _me = 0;

  @override
  void initState() {
    super.initState();
    Session.load().then((u) {
      if (mounted) setState(() => _me = u?.id ?? -1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mine = widget.mine;
    return Scaffold(
      appBar: AppBar(title: Text(mine ? 'My subscriptions' : 'My subscribers')),
      body: _me == 0
          ? const Center(child: CircularProgressIndicator())
          : PagedList(
              path: mine
                  ? 'subscriptions/my-subscription-list?expand=subscribedPlanStatus,subscriptionUserDetail,subscriptionUserDetail.subscribedStatus'
                  : 'subscriptions/subscriber-list?user_id=$_me&expand=subscribedPlanStatus,subscriberDetail,subscriberDetail.subscribedStatus',
              listKey: mine ? 'subscription' : 'subscriber',
              empty: mine ? 'You have not subscribed to anyone' : 'No subscribers yet',
              builder: (c, it) {
                final d = it[mine ? 'subscriptionUserDetail' : 'subscriberDetail'];
                if (d == null) return const SizedBox.shrink();
                final u = AppUser.fromJson(d);
                return Card(
                  elevation: 0,
                  child: ListTile(
                    leading: Avatar(u),
                    title: Text(u.displayName),
                    subtitle: Text('@${u.username}'),
                  ),
                );
              },
            ),
    );
  }
}
