import 'package:flutter/material.dart';
import 'clubs_screen.dart';
import 'competitions_screen.dart';
import 'events_screen.dart';
import 'jobs_screen.dart';
import 'offers_fundraising_screens.dart';
import 'podcasts_screen.dart';
import 'polls_hashtags_screens.dart';
import 'shop_screen.dart';
import 'tv_screen.dart';

class ExploreHub extends StatelessWidget {
  const ExploreHub({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String, Widget)>[
      (Icons.groups_outlined, 'Clubs', 'Join communities', const ClubsScreen()),
      (Icons.event_outlined, 'Events', 'Find things to do', const EventsScreen()),
      (Icons.podcasts_rounded, 'Podcasts', 'Listen to shows', const PodcastsScreen()),
      (Icons.emoji_events_outlined, 'Competitions', 'Join and win', const CompetitionsScreen()),
      (Icons.work_outline_rounded, 'Jobs', 'Browse openings', const JobsScreen()),
      (Icons.local_offer_outlined, 'Offers', 'Coupons and deals', const OffersScreen()),
      (Icons.volunteer_activism_outlined, 'Fundraising', 'Support a cause', const FundraisingScreen()),
      (Icons.tv_rounded, 'TV', 'Shows and channels', const TvScreen()),
      (Icons.poll_outlined, 'Polls', 'Vote and see results', const PollsScreen()),
      (Icons.tag_rounded, 'Hashtags', 'Trending topics', const TrendingScreen()),
      (Icons.storefront_outlined, 'Shop', 'Buy and sell nearby', const ShopScreen()),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(16),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: [
              for (final it in items)
                Card(
                  elevation: 0,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => it.$4)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(it.$1, size: 34, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 8),
                        Text(it.$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(it.$3, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                      ]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
