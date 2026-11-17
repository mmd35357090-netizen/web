import 'package:flutter/material.dart';
import '../app_only.dart';
import 'clubs_screen.dart';
import 'competitions_screen.dart';
import 'dating_screens.dart';
import 'events_screen.dart';
import 'jobs_screen.dart';
import 'offers_fundraising_screens.dart';
import 'podcasts_screen.dart';
import 'polls_hashtags_screens.dart';
import 'shop_screen.dart';
import 'tv_screen.dart';
import 'wallet_screen.dart';

class ExploreHub extends StatelessWidget {
  const ExploreHub({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String, Widget)>[
      (Icons.account_balance_wallet_outlined, 'Wallet & Earn', 'Coins, ads, withdraw', const WalletScreen()),
      (Icons.groups_outlined, 'Clubs', 'Join communities', const ClubsScreen()),
      (Icons.event_outlined, 'Events', 'Find things to do', const EventsScreen()),
      (Icons.podcasts_rounded, 'Podcasts', 'Listen to shows', const PodcastsScreen()),
      (Icons.emoji_events_outlined, 'Competitions', 'Join and win', const CompetitionsScreen()),
      (Icons.work_outline_rounded, 'Jobs', 'Browse openings', const JobsScreen()),
      (Icons.local_offer_outlined, 'Offers', 'Coupons and deals', const OffersScreen()),
      (Icons.volunteer_activism_outlined, 'Fundraising', 'Support a cause', const FundraisingScreen()),
      (Icons.favorite_border_rounded, 'Dating', 'Meet new people', const DatingScreen()),
      (Icons.tv_rounded, 'TV', 'Shows and channels', const TvScreen()),
      (Icons.poll_outlined, 'Polls', 'Vote and see results', const PollsScreen()),
      (Icons.tag_rounded, 'Hashtags', 'Trending topics', const TrendingScreen()),
      (Icons.storefront_outlined, 'Shop', 'Buy and sell nearby', const ShopScreen()),
    ];
    // features that only exist in the mobile app
    final appOnly = <(IconData, String, String)>[
      (Icons.sensors_rounded, 'Live streaming', 'Go live and watch live videos with gifts.'),
      (Icons.call_outlined, 'Voice & video calls', 'Calling needs your phone\'s microphone and camera.'),
      (Icons.monetization_on_outlined, 'Buy coins', 'Coin purchases are made through Google Play / App Store.'),
      (Icons.near_me_outlined, 'Nearby & maps', 'Finding people and places near you needs your phone\'s location.'),
      (Icons.movie_creation_outlined, 'Video editor', 'Editing, filters and music for reels are in the app.'),
      (Icons.notifications_active_outlined, 'Push notifications', 'Get alerts on your phone even when the app is closed.'),
    ];
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            LayoutBuilder(builder: (c, box) {
              final cols = box.maxWidth >= 640 ? 3 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  for (final it in items)
                    Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => it.$4)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(it.$1, size: 32, color: cs.primary),
                            const SizedBox(height: 8),
                            Text(it.$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            Text(it.$3,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.black54, fontSize: 12)),
                          ]),
                        ),
                      ),
                    ),
                ],
              );
            }),
            const SizedBox(height: 24),
            Row(children: [
              Icon(Icons.smartphone_rounded, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              const Text('Only in the mobile app', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 4),
            const Text('These need your phone, so they are not available in the browser.',
                style: TextStyle(color: Colors.black54, fontSize: 13)),
            const SizedBox(height: 10),
            Card(
              child: Column(children: [
                for (int i = 0; i < appOnly.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    leading: Icon(appOnly[i].$1, color: Colors.black54),
                    title: Text(appOnly[i].$2),
                    trailing: const Chip(
                      label: Text('App', style: TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    onTap: () => AppOnly.show(context, appOnly[i].$2, why: appOnly[i].$3),
                  ),
                ],
              ]),
            ),
            if (AppOnly.hasStoreLink) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: AppOnly.openStore,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Get the mobile app'),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
